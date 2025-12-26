//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Core/Vault/IVault.sol";
import "contracts/Strategies/Base/StrategyBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";
import "contracts/Utils/WadMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/External-Interface/ICompoundCometMinimum.sol";

contract CompoundV3LenderUSDC is StrategyBase {
    using SafeERC20 for IERC20;
    using WadMath for uint256;
    using Math for uint256;

    address internal immutable USDC;
    address internal immutable ORACLE_AGGREGATOR;
    address internal immutable USDC_COMET;
    address internal immutable REWARDS;

    constructor(
        address _comptroller,
        address _usdcComet,
        address _rewards,
        address _oracleAggregator,
        address _usdc
    ) {
        USDC = _usdc;
        COMPTROLLER = _comptroller;
        ORACLE_AGGREGATOR = _oracleAggregator;
        USDC_COMET = _usdcComet;
        REWARDS = _rewards;
    }

    function handleDeployFund(
        address _vault,
        bytes calldata _data
    ) internal override onlyComptroller {
        uint256 _amount = abi.decode(_data, (uint256));
        require(_amount > 0, "CompoundV3LenderUSDC: amount is zero");
        IERC20(USDC).safeTransferFrom(_vault, address(this), _amount);
        IERC20(USDC).approve(USDC_COMET, _amount);

        ICompoundCometMinimum(USDC_COMET).supply(USDC, _amount);
    }

    function handleHarvestFund(
        address _vault,
        bytes calldata _data
    ) internal override onlyComptroller {
        uint256 _amount = abi.decode(_data, (uint256));
        require(_amount > 0, "CompoundV3LenderUSDC: amount is zero");
        ICompoundCometMinimum(USDC_COMET).withdraw(USDC, _amount);
        withdrawTo(_vault, USDC, _amount);
    }

    function withdrawTo(address _recipient, address asset, uint256 _amount) internal {
        IERC20(asset).safeTransfer(_recipient, _amount);
    }

    function calcNav() external view override returns (uint256) {
        return calcGav();
    }

    function calcGav() public view override returns (uint256) {
        uint256 valueBaseAsset = ICompoundCometMinimum(USDC_COMET).balanceOf(address(this));
        uint256 valueWad = valueBaseAsset._toWad(6);
        uint256 price = IOraclesAggregator(ORACLE_AGGREGATOR).getPrice(USDC, address(0));
        return valueWad.mulDiv(price, 1e18);
    }
}
