//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/External-Interface/IAaveV3Pool.sol";
import "contracts/Core/Vault/IVault.sol";
import "contracts/Strategies/Base/StrategyBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/External-Interface/IAaveProtocolDataProvider.sol";
import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";
import "contracts/Utils/WadMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// 简单不可升级策略 只接受USDC
contract AaveV3LenderUSDC is StrategyBase {
    using SafeERC20 for IERC20;
    using WadMath for uint256;
    using Math for uint256;

    address internal immutable AAVE_V3_POOL;
    address internal immutable AAVE_PROTOCOL_DATA_PROVIDER;
    address internal immutable USDC;
    address internal immutable ORACLE_AGGREGATOR;

    constructor(
        address _comptroller,
        address _aaveV3Pool,
        address _aaveProtocolDataProvider,
        address _oracleAggregator,
        address _usdc
    ) {
        AAVE_V3_POOL = _aaveV3Pool;
        AAVE_PROTOCOL_DATA_PROVIDER = _aaveProtocolDataProvider;
        USDC = _usdc;
        COMPTROLLER = _comptroller;
        ORACLE_AGGREGATOR = _oracleAggregator;
    }

    function handleDeployFund(
        address _vault,
        bytes calldata _data
    ) internal override onlyComptroller {
        //address _underlying = IVault(_vault).getDenominationAsset(); // USDC资产vault
        (uint256 _amount) = abi.decode(_data, (uint256)); // _to通常是策略自己
        require(_amount > 0, "AaveV3LenderUSDC: amount is zero");
        IERC20(USDC).safeTransferFrom(_vault, address(this), _amount);
        IERC20(USDC).approve(AAVE_V3_POOL, 0);
        IERC20(USDC).approve(AAVE_V3_POOL, _amount);
        IAaveV3Pool(AAVE_V3_POOL).supply(USDC, _amount, address(this), 0);
    }

    function handleHarvestFund(
        address _vault,
        bytes calldata _data
    ) internal override onlyComptroller {
        (uint256 _amount) = abi.decode(_data, (uint256)); // _to通常是Vault
        uint256 receiptAssetsTotalBal = getReceiptAssetsTotalBal();
        if (_amount > receiptAssetsTotalBal) {
            _amount = receiptAssetsTotalBal;
        }
        require(_amount > 0, "AaveV3LenderUSDC: amount is zero");
        IAaveV3Pool(AAVE_V3_POOL).withdraw(USDC, _amount, _vault);
    }

    function getReceiptAssetsTotalBal() public view returns (uint256) {
        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_PROTOCOL_DATA_PROVIDER)
            .getUserReserveData(USDC, address(this));
        return aTokenBal;
    }

    function calcNav() external view override returns (uint256 valueWad_) {
        return calcGav();
    }

    function calcGav() public view override returns (uint256 valueWad_) {
        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_PROTOCOL_DATA_PROVIDER)
            .getUserReserveData(USDC, address(this));
        uint256 valueWadBaseAsset = aTokenBal._toWad(6); // aToken decimals is 6

        uint256 price = IOraclesAggregator(ORACLE_AGGREGATOR).getPrice(USDC, address(0));
        return valueWadBaseAsset.mulDiv(price, 1e18);
    }
}
