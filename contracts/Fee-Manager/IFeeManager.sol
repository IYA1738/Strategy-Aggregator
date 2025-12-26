//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IFeeManager {
    enum FeeType {
        DEPOSIT,
        WITHDRAW,
        REDEEM
    }
    //IFeeManager(FEE_MANAGER).invokeHook(IFeeManager.FeeType.DEPOSIT, _vault, msg.sender, _amount);
    function invokeHook(FeeType feeType, bytes calldata data) external returns (uint256 fee);
}
