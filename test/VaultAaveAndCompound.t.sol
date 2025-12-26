//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase.t.sol";
import "contracts/Strategies/CompoundV3LenderUSDC.sol";
import "contracts/External-Interface/ICompoundCometMinimum.sol";
import "forge-std/console2.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "contracts/Strategies/AaveV3LenderUSDC.sol";
import "contracts/External-Interface/IAaveProtocolDataProvider.sol";

contract VaultAaveAndCompound is VaultTestBase {
    using Math for uint256;
    using SafeERC20 for IERC20;

    address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_DATA_PROVIDER = 0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A;
    AaveV3LenderUSDC aaveV3LenderUSDC;

    CompoundV3LenderUSDC compoundV3LenderUSDC;
    address constant Comet = 0xb125E6687d4313864e53df431d5425969c15Eb2F; // Base mainnet USDC Comet
    address constant Rewards = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;

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

    function test_deployAndharvest(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= 1000);

        uint256 beforeBal = IERC20(USDC).balanceOf(user);
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6);
        vm.stopPrank();

        // 假设这次的配比是AAVE 70% + Compound 30%

        uint256 balOfVault = IERC20(USDC).balanceOf(address(vault));
        uint256 amountAave = balOfVault.mulDiv(70, 100, Math.Rounding.Floor);
        uint256 amountCompound = balOfVault - amountAave;

        vm.startPrank(deployer);

        bytes memory dataAave = abi.encode(amountAave);
        bytes memory dataCompound = abi.encode(amountCompound);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            amountAave,
            dataAave
        );

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(compoundV3LenderUSDC),
            amountCompound,
            dataCompound
        );

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 300_000);

        uint256 aTokenBal = aaveV3LenderUSDC.getReceiptAssetsTotalBal();
        dataAave = abi.encode(aTokenBal);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            0,
            dataAave
        );

        uint256 comet = ICompoundCometMinimum(Comet).balanceOf(address(compoundV3LenderUSDC));
        dataCompound = abi.encode(comet);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(compoundV3LenderUSDC),
            0,
            dataCompound
        );

        vm.stopPrank();

        vm.startPrank(user);
        uint256 _sharesQuantity = IERC20(address(vault)).balanceOf(user);
        comptroller.redeemInKind(user, address(vault), _sharesQuantity);
        vm.stopPrank();

        uint256 afterBal = IERC20(USDC).balanceOf(user);

        console2.log("amount", _amount * 1e6);
        console2.log("beforeBal", beforeBal);
        console2.log("afterBal", afterBal);

        assertGt(afterBal, beforeBal);
    }
}
