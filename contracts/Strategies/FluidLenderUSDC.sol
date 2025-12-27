//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Strategies/Base/StrategyBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";
import "contracts/Utils/WadMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/External-Interface/IFluidFtokenMinimum.sol";

contract FluidLenderUSDC is StrategyBase {
    using SafeERC20 for IERC20;
    using WadMath for uint256;
    using Math for uint256;

    address internal immutable FUSDC;
    address internal immutable ORACLE_AGGREGATOR;
    address internal immutable USDC;

    event FluidLenderDeployFund(address indexed _vault, uint256 _amount, uint256 _executeTime);
    event FluidLenderHarvestFund(
        address indexed _vault,
        uint256 _sharesAmount,
        uint256 _executeTime
    );

    constructor(address _comptroller, address _fusdc, address _oracleAggregator, address _usdc) {
        FUSDC = _fusdc;
        COMPTROLLER = _comptroller;
        ORACLE_AGGREGATOR = _oracleAggregator;
        USDC = _usdc;
    }

    function handleDeployFund(
        address _vault,
        bytes calldata _data
    ) internal override onlyComptroller {
        (uint256 _amount) = abi.decode(_data, (uint256));
        IERC20(USDC).safeTransferFrom(_vault, address(this), _amount);
        IERC20(USDC).approve(FUSDC, 0);
        IERC20(USDC).approve(FUSDC, _amount);
        IFluidFtokenMinimum(FUSDC).deposit(_amount, address(this));
        emit FluidLenderDeployFund(_vault, _amount, block.timestamp);
    }

    function handleHarvestFund(
        address _vault,
        bytes calldata _data
    ) internal override onlyComptroller {
        (uint256 _shareAmount) = abi.decode(_data, (uint256));
        IFluidFtokenMinimum(FUSDC).redeem(_shareAmount, _vault, address(this));
        emit FluidLenderHarvestFund(_vault, _shareAmount, block.timestamp);
    }

    function calcGav() public view override returns (uint256) {
        uint256 totalSharesAmount = IERC20(FUSDC).balanceOf(address(this));
        uint256 assetAmount = IFluidFtokenMinimum(FUSDC).convertToAssets(totalSharesAmount);
        uint8 _dec = IERC20Metadata(IFluidFtokenMinimum(FUSDC).asset()).decimals();
        uint256 price = IOraclesAggregator(ORACLE_AGGREGATOR).getPrice(USDC, address(0));
        uint256 assetAmountWad = assetAmount._toWad(_dec);
        return assetAmountWad.mulDiv(price, 1e18);
    }

    function calcNav() external view override returns (uint256) {
        return calcGav();
    }

    function strategySupportAsset() public view override returns (address) {
        return USDC;
    }
}
