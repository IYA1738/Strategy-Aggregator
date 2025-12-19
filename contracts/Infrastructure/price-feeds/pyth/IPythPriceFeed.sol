//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPythPriceFeed{
    function isPairExist(address _tokenA) external view returns(bool);
    function getPrice(address _tokenA) external view returns(uint256 priceE18, uint256 publishTime);
}