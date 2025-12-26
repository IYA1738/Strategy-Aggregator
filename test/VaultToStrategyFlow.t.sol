//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase.t.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "contracts/Strategies/AaveV3LenderUSDC.sol";
import "contracts/External-Interface/IAaveProtocolDataProvider.sol";

contract VaultToStrategyFlowTest is VaultTestBase {
    address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_DATA_PROVIDER = 0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A;
    AaveV3LenderUSDC aaveV3LenderUSDC;

    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        aaveV3LenderUSDC = new AaveV3LenderUSDC(
            address(comptroller),
            AAVE_V3_POOL,
            AAVE_DATA_PROVIDER,
            address(agg),
            USDC
        );
        aaveV3LenderUSDC.setManager(deployer);
        vault.registryStreategy(address(aaveV3LenderUSDC));
        aaveV3LenderUSDC.setAllowedVault(address(vault), true);
        vm.stopPrank();
    }

    function test_pushUSDC_to_strategy(uint256 _amount) external {
        vm.assume(_amount > 0 && _amount <= 1000);
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6); // 1 USDC
        vm.stopPrank();

        vm.startPrank(deployer);

        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            _amount * 1e6,
            _data
        );

        vm.stopPrank();

        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        assertGt(aTokenBal, 0);
    }

    function test_pullUSDC_from_strategy(uint256 _amount) external {
        vm.assume(_amount > 0 && _amount <= 1000);
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6); // 1 USDC
        vm.stopPrank();

        vm.startPrank(deployer);

        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            _amount * 1e6,
            _data
        );

        vm.stopPrank();

        vm.startPrank(deployer);
        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        uint256 vaultBal = IERC20(USDC).balanceOf(address(vault));

        assertEq(vaultBal, 0);

        _data = abi.encode(aTokenBal);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            aTokenBal,
            _data
        );

        assertApproxEqRel(IERC20(USDC).balanceOf(address(vault)), _amount * 1e6, 1e14);

        (aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        assertApproxEqRel(aTokenBal, 0, 1e14);

        vm.stopPrank();
    }
}
