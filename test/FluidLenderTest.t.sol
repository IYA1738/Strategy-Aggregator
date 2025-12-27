//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase.t.sol";
import "contracts/Strategies/FluidLenderUSDC.sol";

contract FluidLenderTest is VaultTestBase {
    address FUSDC = 0xf42f5795D9ac7e9D757dB633D693cD548Cfd9169;
    FluidLenderUSDC fluidLenderUSDC;
    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        fluidLenderUSDC = new FluidLenderUSDC(address(comptroller), FUSDC, address(agg), USDC);
        fluidLenderUSDC.setManager(deployer);
        vault.registryStreategy(address(fluidLenderUSDC));
        fluidLenderUSDC.setAllowedVault(address(vault), true);
        vm.stopPrank();
    }

    // 暂时不开手续费
    function test_deployAndHarvestFund(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1000);
        uint256 userUsdcBefore = IERC20(USDC).balanceOf(user);
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6);
        vm.stopPrank();

        vm.startPrank(deployer);

        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(fluidLenderUSDC),
            _amount * 1e6,
            _data
        );

        vm.stopPrank();

        uint256 sharesAmount = IERC20(FUSDC).balanceOf(address(fluidLenderUSDC));

        assertGt(sharesAmount, 0);

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 900000);

        vm.startPrank(deployer);

        _data = abi.encode(sharesAmount);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(fluidLenderUSDC),
            0,
            _data
        );
        vm.stopPrank();

        uint256 sharesAmountAfterHarvest = IERC20(FUSDC).balanceOf(address(fluidLenderUSDC));
        assertEq(sharesAmountAfterHarvest, 0);

        vm.startPrank(user);
        uint256 _sharesQuantity = type(uint256).max;
        comptroller.redeemInKind(user, address(vault), _sharesQuantity);
        vm.stopPrank();

        uint256 userUsdcAfter = IERC20(USDC).balanceOf(user);

        assertGt(userUsdcAfter, userUsdcBefore);

        //===== log =====
        console2.log("Amount =", _amount * 1e6);
        console2.log("SharesAmount", sharesAmount);
        console2.log("User usdc before = ", userUsdcBefore);
        console2.log("User usdc after = ", userUsdcAfter);
        if (userUsdcAfter >= userUsdcBefore) {
            console2.log("profit=", userUsdcAfter - userUsdcBefore);
        } else {
            console2.log("loss=", userUsdcBefore - userUsdcAfter);
        }
    }
}
