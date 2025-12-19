//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Infrastructure/price-feeds/pyth/IPythPriceFeed.sol";
import "contracts/Infrastructure/price-feeds/utils/OraclesAggregatorOwnerMixin.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythPriceFeed is IPythPriceFeed ,OraclesAggregatorOwnerMixin{

    IPyth public immutable PYTH;

    mapping(address => bytes32) private _pythPriceIds;

    uint256 public constant MAX_PRICE_AGE = 3 seconds;

    event PythPriceIdSet(address indexed token, bytes32 indexed priceId);

    constructor(address _oraclesAggregator, address _pyth) OraclesAggregatorOwnerMixin(_oraclesAggregator){
        require(_pyth != address(0), "Invalid Pyth address");
        PYTH = IPyth(_pyth);
    }

    function getPrice(address _tokenA)
    external
    view
    override
    onlyOraclesAggregatorOwner
    returns(uint256 priceE18, uint256 publishTime){
        bytes32 priceId = _pythPriceIds[_tokenA];
        require(priceId != bytes32(0), "PythPriceFeed: Price ID not set for token");

        PythStructs.Price memory p = PYTH.getPriceNoOlderThan(priceId, MAX_PRICE_AGE);
        require(p.price > 0, "PythPriceFeed: Invalid price from Pyth");

        int256 price = p.price;
        int256 expo = int256(p.expo);

        int256 targetExpo = 18 + expo;

        if(targetExpo >= 0) {
            uint256 factor = 10 ** uint256(targetExpo);
            priceE18 = uint256(price) * factor;
        } else{
            uint256 factor = 10 ** uint256(-targetExpo);
            priceE18 = uint256(price) / factor;
        }
        publishTime = p.publishTime;
    }

    function isPairExist(address _tokenA) external view override returns(bool){
        bytes32 priceId = _pythPriceIds[_tokenA];
        return priceId != bytes32(0);
    }

    function setPythPriceId(address token, bytes32 priceId) external onlyOraclesAggregatorOwner{
        require(token != address(0), "Invalid token address");
        require(priceId != bytes32(0), "Invalid priceId");
        _pythPriceIds[token] = priceId;
        emit PythPriceIdSet(token, priceId);
    }
    
}