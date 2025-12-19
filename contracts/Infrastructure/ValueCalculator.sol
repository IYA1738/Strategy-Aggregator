//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";
import "contracts/Core/Vault/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ValueCalculator {
    address private immutable ORACLES_AGGREGATOR;

    constructor(address _oraclesAggregator) {
        require(_oraclesAggregator != address(0), "Invalid address");
        ORACLES_AGGREGATOR = _oraclesAggregator;
    }

    function calcNav(address _vault) external view returns (uint256) {
        // nav = gav - 欠款protocolFee
    }

    function calcGav(address _vault) public view returns (uint256) {
        address[] memory trackedAssets = IVault(_vault).getTrackedAssets();
        address denominationAsset = IVault(_vault).getDenominationAsset();
        uint256 gav = 0;
        for (uint256 i = 0; i < trackedAssets.length; ) {
            address asset = trackedAssets[i];
            uint256 assetBalance = IERC20(asset).balanceOf(_vault);
            uint256 price = IOraclesAggregator(ORACLES_AGGREGATOR).getPrice(
                asset,
                denominationAsset
            );
            gav += assetBalance * price;
            unchecked {
                i++;
            }
        }
        return gav;
    }
}
