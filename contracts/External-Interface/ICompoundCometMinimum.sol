// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICompoundCometMinimum {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;

    function balanceOf(address owner) external view returns (uint256);

    function baseToken() external view returns (address);
    function baseScale() external view returns (uint256);
}
