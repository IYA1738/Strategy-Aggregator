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

contract VaultFlowTest is Test {
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

    function setUp() external {
        string memory RPC = "https://base-mainnet.infura.io/v3/c8b8880b688449e098c268f568bf7700"; //上传github前要删掉
        vm.createSelectFork(RPC);

        bytes memory libCode = vm.getCode("VaultConfigLib.sol:VaultConfigLib");
        vm.etch(LIB_ADDR, libCode);

        vm.deal(user, 10 ether);
        vm.deal(deployer, 10 ether);

        deal(USDC, user, 1_0000 * 1e6);
        deal(USDC, deployer, 1_0000 * 1e6);

        vm.startPrank(deployer);

        agg = new OraclesAggregator(deployer, address(0), address(0));

        clFeed = new ChainLinkPriceFeed(address(agg), 1 days);
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

    function test_deposit_usdc() external {
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);

        uint256 beforeBal = IERC20(USDC).balanceOf(user);

        comptroller.deposit(address(vault), 1e6); // 1 USDC

        uint256 afterBal = IERC20(USDC).balanceOf(user);

        vm.stopPrank();

        assertEq(beforeBal - afterBal, 1e6);
    }

    function test_deposit_checkSharesAmount(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 1000);

        uint256 amountToken = amount * 1e6; // USDC 6 decimals
        uint256 amountWad = amount * 1e18;

        uint256 expectedShares = 0;

        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);

        {
            uint256 preSupply = IERC20(address(vault)).totalSupply();
            uint256 preNavWad = valueCalc.calcNav(address(vault));

            uint256 mint1;
            if (preSupply == 0) {
                mint1 = amountWad;
            } else {
                require(preNavWad > 0, "preNav=0");
                mint1 = Math.mulDiv(amountWad, preSupply, preNavWad, Math.Rounding.Floor);
            }

            expectedShares += mint1;
            comptroller.deposit(address(vault), amountToken);
        }

        {
            uint256 preSupply = IERC20(address(vault)).totalSupply();
            uint256 preNavWad = valueCalc.calcNav(address(vault));
            require(preNavWad > 0, "preNav=0");

            uint256 mint2 = Math.mulDiv(amountWad, preSupply, preNavWad, Math.Rounding.Floor);
            expectedShares += mint2;

            comptroller.deposit(address(vault), amountToken);
        }

        uint256 sharesBal = IERC20(address(vault)).balanceOf(user);
        vm.stopPrank();

        assertEq(sharesBal, expectedShares);
    }

    function test_redeemInKind_usdc(uint256 _amount) external {
        vm.assume(_amount > 0 && _amount <= 1000);

        uint256 beforeBal = IERC20(USDC).balanceOf(user);
        vm.assume(beforeBal > 0);

        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);

        comptroller.deposit(address(vault), _amount * 1e6);
        comptroller.deposit(address(vault), _amount * 1e6);

        uint256 sharesBal = IERC20(address(vault)).balanceOf(user);

        comptroller.redeemInKind(user, address(vault), type(uint256).max);

        uint256 afterBal = IERC20(USDC).balanceOf(user);
        vm.stopPrank();

        // 0.2% relative tolerance
        assertApproxEqRel(afterBal, beforeBal, 2e15);
        assertEq(IERC20(address(vault)).balanceOf(user), 0);
        assertGt(sharesBal, 0); //确认不是空跑流程导致的不变量守恒
    }

    function test_deposit_whenVaultHasUsdcAaveAndSupply_mintsCorrectShares(uint256 amt) external {
        vm.assume(amt > 0 && amt <= 1000);

        // ========= 0) 确保 vault 已经 tracked 了 USDC + AAVE =========
        // 如果你 setUp() 已经做了，就可以删掉这两行
        // vm.prank(deployer);
        // vault.addTrackedAsset(AAVE);

        // ========= 1) 先做“种子状态”：让 vault 已有 supply + USDC =========
        // 让 deployer 先存 seedUsdc，铸造初始 shares（保证 preSupply>0）
        uint256 seedUsdc = 1000e6; // 1000 USDC
        vm.startPrank(deployer);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), seedUsdc);
        vm.stopPrank();

        // ========= 2) 给 vault 一点 AAVE（让 NAV 变成“多资产”） =========
        // 例如 1 AAVE（AAVE 18 decimals）
        deal(AAVE, address(vault), 1e18);

        // ========= 3) 记录 pre 状态：preSupply + preNav =========
        uint256 preSupply = IERC20(address(vault)).totalSupply();
        uint256 preNavUsdWad = valueCalc.calcNav(address(vault)); // USD, 1e18
        assertGt(preSupply, 0);
        assertGt(preNavUsdWad, 0);

        // ========= 4) 计算本次 deposit 的 USD 价值 =========
        // amt 是“整 USDC”，存款 raw 是 6dec
        uint256 raw = amt * 1e6;

        // USDC -> wad
        uint256 usdcWad = amt * 1e18;

        // USDC/USD 价格（1e18）
        uint256 pxUsdcUsd = agg.getPrice(USDC, USD);
        assertGt(pxUsdcUsd, 0);

        // depositValueUsdWad = usdcWad * px / 1e18
        uint256 depositValueUsdWad = Math.mulDiv(usdcWad, pxUsdcUsd, 1e18, Math.Rounding.Floor);
        assertGt(depositValueUsdWad, 0);

        // expectedMint = depositValueUsdWad * preSupply / preNavUsdWad
        uint256 expectedMint = Math.mulDiv(
            depositValueUsdWad,
            preSupply,
            preNavUsdWad,
            Math.Rounding.Floor
        );

        // ========= 5) 执行被测 deposit（user） =========
        uint256 preUserShares = IERC20(address(vault)).balanceOf(user);

        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), raw);
        vm.stopPrank();

        uint256 minted = IERC20(address(vault)).balanceOf(user) - preUserShares;

        // ========= 6) 断言：允许 0.01% 误差（取整 + oracle rounding） =========
        assertApproxEqRel(minted, expectedMint, 2e15); //
    }
}
