//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase2.t.sol";

contract ChargeOperationFee is VaultTestBase2 {
    function setUp() public override {
        super.setUp();
    }

    function test_chargeDepositFee() public {
        vm.startPrank(deployer);
        vault.setDepositFeeRateBps(100); // 1%
        vm.stopPrank();

        uint256 amount = 1000;

        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amount * 1e6);

        vm.stopPrank();

        uint256 feeToMint = IERC20(address(vault)).balanceOf(address(feeReserver));
        assertGt(feeToMint, 0);

        uint256 sharesToMint = IERC20(address(vault)).balanceOf(user);

        console2.log("Fee To Mint =", feeToMint / 1e12);
        console2.log("Shares To Mint =", sharesToMint / 1e12);
    }
}
