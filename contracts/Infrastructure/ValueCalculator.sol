// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";
import "contracts/Core/Vault/IVault.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ValueCalculator {
    uint256 internal constant WAD = 1e18;
    address private immutable ORACLES_AGGREGATOR;

    constructor(address _oraclesAggregator) {
        require(_oraclesAggregator != address(0), "Invalid address");
        ORACLES_AGGREGATOR = _oraclesAggregator;
    }

    // 用于测试其他模块时的版本， 暂时先这样, 后续继续补足真实计算逻辑
    function calcNav(address _vault) external view returns (uint256) {
        address[] memory strategies = IVault(_vault).getStrategies();
        uint256 length = strategies.length;
        uint256 strategiesNavWad = 0;
        for (uint256 i = 0; i < length; ) {
            address strategy = strategies[i];
            uint256 navWad = IStrategyBase(strategy).calcNav();
            strategiesNavWad += navWad;
            unchecked {
                i++;
            }
        }
        return calcGav(_vault) + strategiesNavWad;
    }

    function calcGav(address _vault) public view returns (uint256 gavWad) {
        address[] memory trackedAssets = IVault(_vault).getTrackedAssets();

        for (uint256 i = 0; i < trackedAssets.length; ) {
            address asset = trackedAssets[i];
            uint256 balRaw = IERC20(asset).balanceOf(_vault);

            if (balRaw != 0) {
                uint8 aDec = IERC20Metadata(asset).decimals();
                uint256 balWad = _toWad(balRaw, aDec);
                uint256 priceE18 = IOraclesAggregator(ORACLES_AGGREGATOR).getPrice(
                    asset,
                    address(0) // USD Flag
                );
                gavWad += Math.mulDiv(balWad, priceE18, WAD, Math.Rounding.Floor);
            }

            unchecked {
                i++;
            }
        }
    }

    function _toWad(uint256 amountRaw, uint8 dec) internal pure returns (uint256) {
        if (dec == 18) return amountRaw;
        if (dec < 18) return amountRaw * (10 ** (18 - dec));
        return amountRaw / (10 ** (dec - 18));
    }
}
