//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "lib/forge-std/src/Test.sol";

import "contracts/Core/Vault/Vault.sol";
import "contracts/Core/Vault/VaultFactory.sol";
import "contracts/Utils/VaultConfigLib.sol";
import "contracts/Infrastructure/ValueCalculator.sol";
import "contracts/Fee-Manager/FeeManager.sol";
import "contracts/Core/Comptroller/VaultComptroller.sol";
import "contracts/Infrastructure/price-feeds/OraclesAggregator.sol";
import "contracts/Infrastructure/price-feeds/chainlink/ChainLinkPriceFeed.sol";
import "contracts/Infrastructure/price-feeds/pyth/PythPriceFeed.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/Fee-Reserver/FeeReserver.sol";
import "forge-std/console2.sol";

abstract contract VaultTestBase is Test {
    address constant USD = address(0);
    address constant LIB_ADDR = 0x1000000000000000000000000000000000000001;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant PYTH = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AAVE = 0x63706e401c06ac8513145b7687A14804d17f814b;

    // Chainlink USDC/USD
    address constant CL_USDC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    // Pyth priceId：USDC/USD 对应的 bytes32
    bytes32 constant PYTH_USDC_USD_ID =
        bytes32(0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a);

    address user = makeAddr("user");
    address deployer = makeAddr("deployer");

    address constant CL_AAVE_USD = 0x3d6774EF702A10b20FCa8Ed40FC022f7E4938e07;
    bytes32 constant PYTH_AAVE_USD_ID =
        bytes32(0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445);

    OraclesAggregator agg;
    ChainLinkPriceFeed clFeed;
    PythPriceFeed pythFeed;

    FeeManager feeManager;
    ValueCalculator valueCalc;
    VaultComptroller comptroller;

    VaultFactory factory;
    Vault vault;

    FeeReserver feeReserver;

    function setUp() public virtual {
        uint256 forkBlock = 39000000;
        string memory RPC = ""; //上传github前要删掉
        vm.createSelectFork(RPC, forkBlock);

        bytes memory libCode = vm.getCode("VaultConfigLib.sol:VaultConfigLib");
        vm.etch(LIB_ADDR, libCode);

        vm.deal(user, 10 ether);
        vm.deal(deployer, 10 ether);

        deal(USDC, user, 1_0000 * 1e6);
        deal(USDC, deployer, 1_0000 * 1e6);

        vm.startPrank(deployer);

        agg = new OraclesAggregator(deployer, address(0), address(0));

        clFeed = new ChainLinkPriceFeed(address(agg), 999 days);
        pythFeed = new PythPriceFeed(address(agg), PYTH);

        agg.setChainLinkPriceFeed(address(clFeed));
        agg.setPythPriceFeed(address(pythFeed));

        feeReserver = new FeeReserver();
        feeManager = new FeeManager();
        valueCalc = new ValueCalculator(address(agg));
        comptroller = new VaultComptroller(
            WETH,
            address(feeManager),
            address(valueCalc),
            address(feeReserver)
        );
        factory = new VaultFactory();
        vault = Vault(
            factory.createVault(
                address(comptroller),
                USDC,
                deployer,
                address(feeReserver),
                0,
                "Vault",
                "VAULT"
            )
        );

        comptroller.addTrackedVault(address(vault));

        vault.addTrackedAsset(USDC);
        vault.addTrackedAsset(AAVE);

        clFeed.setPriceFeed(USDC, USD, CL_USDC_USD);
        pythFeed.setPythPriceId(USDC, PYTH_USDC_USD_ID);
        clFeed.setPriceFeed(AAVE, USD, CL_AAVE_USD);
        pythFeed.setPythPriceId(AAVE, PYTH_AAVE_USD_ID);

        vm.stopPrank();
    }
}
