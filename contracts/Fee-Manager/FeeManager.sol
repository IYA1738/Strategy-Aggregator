//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Fee-Manager/IFeeManager.sol";
import "contracts/Utils/VaultConfigLib.sol";
import "contracts/Core/Vault/IVault.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract FeeManager is IFeeManager {
    using VaultConfigLib for uint256;
    using Math for uint256;

    function invokeHook(
        FeeType feeType,
        bytes calldata data
    ) external view override returns (uint256 fee) {
        if (feeType == FeeType.DEPOSIT) {
            return _handleDepositHook(data);
        } else if (feeType == FeeType.WITHDRAW) {
            return 0;
        } else if (feeType == FeeType.REDEEM) {
            return _handleRedeemHook(data);
        }
    }

    function _handleDepositHook(bytes calldata data) private view returns (uint256 fee) {
        (address vault, uint256 amount) = abi.decode(data, (address, uint256));
        uint256 config = IVault(vault).getVaultConfig();
        uint256 depositFeeRateBps = config.getDepositFeeRateBps();
        if (depositFeeRateBps == 0) return 0;
        return amount.mulDiv(depositFeeRateBps, 10_000, Math.Rounding.Floor);
    }

    function _handleRedeemHook(bytes calldata data) private view returns (uint256 fee) {
        (address vault, uint256 shareToRedeem) = abi.decode(data, (address, uint256));
        uint256 config = IVault(vault).getVaultConfig();
        uint256 redeemFeeRateBps = config.getRedeemFeeRateBps();
        if (redeemFeeRateBps == 0) return 0;
        return shareToRedeem.mulDiv(redeemFeeRateBps, 10_000, Math.Rounding.Floor);
    }
}
