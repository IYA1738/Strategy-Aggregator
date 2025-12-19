//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Infrastructure/price-feeds/IOraclesAggregator.sol";

abstract contract OraclesAggregatorOwnerMixin{
    address public immutable ORACLES_AGGREGATOR;

    modifier onlyOraclesAggregatorOwner(){
        require(msg.sender == IOraclesAggregator(ORACLES_AGGREGATOR).owner(), "Only OraclesAggregator Owner");
        _;
    }

    constructor(address _oraclesAggregator){
        require(_oraclesAggregator != address(0), "Invalid address");
        ORACLES_AGGREGATOR = _oraclesAggregator;
    }

    function getOwner() external view returns(address){
        return IOraclesAggregator(ORACLES_AGGREGATOR).owner();
    }

    function getOraclesAggregator() external view returns(address){
        return ORACLES_AGGREGATOR;
    }

}