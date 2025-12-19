//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "contracts/Infrastructure/price-feeds/utils/OraclesAggregatorOwnerMixin.sol";
import "contracts/Infrastructure/price-feeds/chainlink/IChainLinkPriceFeed.sol";

contract ChainLinkPriceFeed is IChainLinkPriceFeed, OraclesAggregatorOwnerMixin {
    mapping(address => mapping(address => address)) public priceFeeds; // tokenA => tokenB => priceFeedAddress

    address public oraclesAggregator;

    uint256 public constant MAX_EXPIRED_TIME = 1 minutes;
    uint256 public expiredTime;

    event PriceFeedUpdated(address indexed tokenA, address indexed tokenB, address indexed priceFeed);
    event OraclesAggregatorUpdated(address indexed oraclesAggregator);
    event ExpiredTimeUpdated(uint256 expiredTime);

    modifier onlyOraclesAggregator() {
        require(msg.sender == oraclesAggregator, "ChainLinkPriceFeed: Caller is not the OraclesAggregator");
        _;
    }

    constructor(address _oraclesAggregator, uint256 _expiredTime) OraclesAggregatorOwnerMixin(_oraclesAggregator) {
        require(_expiredTime <= MAX_EXPIRED_TIME, "ChainLinkPriceFeed: Exceeded maximum expired time");
        oraclesAggregator = _oraclesAggregator;
        expiredTime = _expiredTime;
    }

    function getPrice(address _tokenA, address _tokenB) external view onlyOraclesAggregator returns(uint256){
        require(priceFeeds[_tokenA][_tokenB] != address(0), "ChainLinkPriceFeed: Price feed not set for this pair");
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[_tokenA][_tokenB]);
        (,int256 price,,uint256 updatedAt,) = priceFeed.latestRoundData();
        require(price > 0, "ChainLinkPriceFeed: Invalid price data");
        require(block.timestamp - updatedAt <= expiredTime, "ChainLinkPriceFeed: Price data is expired");
        uint8 decimals = priceFeed.decimals();
        return uint256(price) * (10 ** (18 - decimals)); // Normalize to 18 decimals
    }

    function setExpiredTime(uint256 _expiredTime) external onlyOraclesAggregatorOwner{
        require(_expiredTime <= MAX_EXPIRED_TIME, "ChainLinkPriceFeed: Exceeded maximum expired time");
        expiredTime = _expiredTime;
        emit ExpiredTimeUpdated(_expiredTime);
    }
    
    function setPriceFeed(address _tokenA, address _tokenB, address _priceFeed) external onlyOraclesAggregatorOwner{ 
        require(_tokenA != address(0), "ChainLinkPriceFeed: Invalid tokenA");
        require(_tokenB != address(0), "ChainLinkPriceFeed: Invalid tokenB");
        require(_priceFeed != address(0), "ChainLinkPriceFeed: Invalid priceFeed");
        require(priceFeeds[_tokenA][_tokenB] == address(0), "ChainLinkPriceFeed: Price feed already set for this pair");
        priceFeeds[_tokenA][_tokenB] = _priceFeed;
        emit PriceFeedUpdated(_tokenA, _tokenB, _priceFeed);
    }

    function setOraclesAggregator(address _oraclesAggregator) external onlyOraclesAggregatorOwner { 
        require(_oraclesAggregator != address(0), "ChainLinkPriceFeed: Invalid OraclesAggregator");
        oraclesAggregator = _oraclesAggregator;
        emit OraclesAggregatorUpdated(_oraclesAggregator);
    }

    function isPairExist(address _tokenA, address _tokenB) external view returns(bool){
        return priceFeeds[_tokenA][_tokenB] != address(0);
    }
}