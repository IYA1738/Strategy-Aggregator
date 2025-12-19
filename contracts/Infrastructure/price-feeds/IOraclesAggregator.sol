//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IOraclesAggregator{
    function getPrice(address _tokenA, address _tokenB) external view returns(uint256);

    function owner() external view returns(address);
}