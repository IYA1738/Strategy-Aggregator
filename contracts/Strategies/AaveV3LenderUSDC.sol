//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/External-Interface/IAaveV3Pool.sol";
import "contracts/Core/Vault/IVault.sol";
import "contracts/Strategies/Base/StrategyBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// 简单不可升级策略 只接受USDC
contract AaveV3LenderUSDC is StrategyBase {
    using SafeERC20 for IERC20;

    address internal immutable AAVE_V3_POOL;
    // AToken
    address internal immutable receiptAssets;

    constructor(address _aaveV3Pool, address _receiptAssets) {
        AAVE_V3_POOL = _aaveV3Pool;
        receiptAssets = _receiptAssets;
    }

    function handleDeployFund(address _vault, bytes calldata _data) internal override onlyManager {
        address _underlying = IVault(_vault).getDenominationAsset(); // USDC资产vault
        (uint256 _amount) = abi.decode(_data, (uint256)); // _to通常是策略自己
        require(_amount > 0, "AaveV3LenderUSDC: amount is zero");
        IERC20(_underlying).safeTransferFrom(_vault, address(this), _amount);
        IERC20(_underlying).approve(AAVE_V3_POOL, 0);
        IERC20(_underlying).approve(AAVE_V3_POOL, _amount);
        IAaveV3Pool(AAVE_V3_POOL).supply(_underlying, _amount, address(this), 0);
    }

    function handleHarvestFund(address _vault, bytes calldata _data) internal override onlyManager {
        address _underlying = IVault(_vault).getDenominationAsset(); // USDC资产vault
        (uint256 _amount) = abi.decode(_data, (uint256)); // _to通常是Vault
        uint256 receiptAssetsTotalBal = getReceiptAssetsTotalBal();
        if (_amount > receiptAssetsTotalBal) {
            _amount = receiptAssetsTotalBal;
        }
        require(_amount > 0, "AaveV3LenderUSDC: amount is zero");
        IAaveV3Pool(AAVE_V3_POOL).withdraw(_underlying, _amount, _vault);
    }

    function getReceiptAssetsTotalBal() public view returns (uint256) {
        return IERC20(receiptAssets).balanceOf(address(this));
    }
}
