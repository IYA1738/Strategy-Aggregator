//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase.t.sol";
import "contracts/Strategies/CompoundV3LenderUSDC.sol";
import "contracts/External-Interface/ICompoundCometMinimum.sol";
import "forge-std/console2.sol";

contract CompoundV3USDC is VaultTestBase {
    CompoundV3LenderUSDC compoundV3LenderUSDC;
    address constant Comet = 0xb125E6687d4313864e53df431d5425969c15Eb2F; // Base mainnet USDC Comet
    address constant Rewards = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        compoundV3LenderUSDC = new CompoundV3LenderUSDC(
            address(comptroller),
            Comet,
            Rewards,
            address(agg),
            USDC
        );
        compoundV3LenderUSDC.setManager(deployer);
        vault.registryStreategy(address(compoundV3LenderUSDC));
        compoundV3LenderUSDC.setAllowedVault(address(vault), true);

        vm.stopPrank();
    }

    function test_deployFund(uint256 _amount) external {
        vm.assume(_amount > 0 && _amount <= 1000);

        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6);
        vm.stopPrank();

        vm.startPrank(deployer);

        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(compoundV3LenderUSDC),
            _amount * 1e6,
            _data
        );

        vm.stopPrank();

        console2.log("Amount =", _amount * 1e6);
        console2.log(
            "Comet Amount:",
            ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC))
        );

        assertGt(ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC)), 0);
    }

    function test_deployFund_foraWhile(uint256 _amount) external {
        vm.assume(_amount > 0 && _amount <= 1000);
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6);
        vm.stopPrank();

        vm.startPrank(deployer);

        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(compoundV3LenderUSDC),
            _amount * 1e6,
            _data
        );

        vm.stopPrank();

        uint256 beforeComet = ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC));

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 900000);

        uint256 afterComet = ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC));

        console2.log("Amount =", _amount * 1e6);
        console2.log("beforeComet", beforeComet);
        console2.log("afterComet", afterComet);

        assertGt(afterComet, beforeComet);
    }

    function test_harvestFund(uint256 _amount) external {
        vm.assume(_amount > 0 && _amount <= 1000);

        uint256 beforeBal = IERC20(USDC).balanceOf(user);

        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6); // 1 USDC
        vm.stopPrank();

        vm.startPrank(deployer);

        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(compoundV3LenderUSDC),
            _amount * 1e6,
            _data
        );

        assertGt(ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC)), 0); // 防空跑

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 900000);

        _data = abi.encode(ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC)));

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(compoundV3LenderUSDC),
            0,
            _data
        );

        vm.stopPrank();

        assertApproxEqAbs(
            ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC)),
            0,
            1e4
        ); // 0.01usdc误差

        vm.startPrank(user);
        comptroller.redeemInKind(user, address(vault), vault.balanceOf(user));
        vm.stopPrank();

        uint256 afterBal = IERC20(USDC).balanceOf(user);

        assertGt(afterBal, beforeBal);

        console2.log("Amount =", _amount * 1e6);
        console2.log("beforeBal", beforeBal);
        console2.log("afterBal", afterBal);
        if (afterBal >= beforeBal) {
            console2.log("profit:", afterBal - beforeBal);
        } else {
            console2.log("loss:", beforeBal - afterBal);
        }
    }
}
