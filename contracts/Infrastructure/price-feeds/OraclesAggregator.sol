//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";
import "contracts/Infrastructure/price-feeds/chainlink/IChainLinkPriceFeed.sol";
import {IPythPriceFeed} from "contracts/Infrastructure/price-feeds/pyth/IPythPriceFeed.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

//All denomination asset is USD/USDC/USDT

contract OraclesAggregator is IOraclesAggregator {
    address private immutable _owner;
    address private _chainLinkPriceFeed; // Main oracle
    address private _pythPriceFeed; // Secondary oracle

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_PRICE_DIFFERENCE_BPS = 1000; // 10%

    constructor(address _timelockOwner, address chainLinkPriceFeed, address pythPriceFeed) {
        _owner = _timelockOwner;
        _chainLinkPriceFeed = chainLinkPriceFeed;
        _pythPriceFeed = pythPriceFeed;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the owner");
        _;
    }

    function getPrice(address _tokenA, address _tokenB) external view override returns (uint256) {
        _checkPairValidity(_tokenA, _tokenB);

        uint256 chainlinkPrice = IChainLinkPriceFeed(_chainLinkPriceFeed).getPrice(
            _tokenA,
            _tokenB
        );
        (uint256 pythPrice, ) = IPythPriceFeed(_pythPriceFeed).getPrice(_tokenA);
        // Already checked time delay in respective price feed contracts
        // 数据延时检查在各自的getPrice中已经检查过了
        _checkPriceMatch(chainlinkPrice, pythPrice);
        return chainlinkPrice;
    }

    function _checkPairValidity(address _tokenA, address _tokenB) internal view {
        require(_tokenA != address(0) && _tokenA != _tokenB, "Invalid token pair");
        bool isChainLinkSupported = IChainLinkPriceFeed(_chainLinkPriceFeed).isPairExist(
            _tokenA,
            _tokenB
        );
        require(isChainLinkSupported, "Pair not supported in Chainlink");
        bool isPythSupported = IPythPriceFeed(_pythPriceFeed).isPairExist(_tokenA);
        require(isPythSupported, "Pair not supported in Pyth");
    }

    function _checkPriceMatch(uint256 _chainLinkPrice, uint256 _pythPrice) internal pure {
        uint256 priceDiff = _chainLinkPrice > _pythPrice
            ? _chainLinkPrice - _pythPrice
            : _pythPrice - _chainLinkPrice;
        //正常做法: priceDiff / _chainLinkPrice <= MAX_PRICE_DIFFERENCE_BPS / BPS
        //避免精度丢失改为 priceDiff <= _chainLinkPrice * MAX_PRICE_DIFFERENCE_BPS / BPS
        //_chainLinkPrice精度1e18, BPS==10000， 所以必然不会出现小数截断
        require(
            priceDiff <= Math.mulDiv(_chainLinkPrice, MAX_PRICE_DIFFERENCE_BPS, BPS),
            "Price difference too high"
        );
    }

    function setChainLinkPriceFeed(address newChainLinkPriceFeed) external onlyOwner {
        require(newChainLinkPriceFeed != address(0), "Invalid address");
        _chainLinkPriceFeed = newChainLinkPriceFeed;
    }

    function setPythPriceFeed(address newPythPriceFeed) external onlyOwner {
        require(newPythPriceFeed != address(0), "Invalid address");
        _pythPriceFeed = newPythPriceFeed;
    }

    function getChainLinkPriceFeed() external view returns (address) {
        return _chainLinkPriceFeed;
    }

    function getPythPriceFeed() external view returns (address) {
        return _pythPriceFeed;
    }

    function owner() public view override returns (address) {
        return _owner;
    }
}
