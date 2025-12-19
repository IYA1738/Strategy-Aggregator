// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICompoundCometMinimum {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;

    // base 资产（例如 USDC）供给余额（注意：不是 aToken，而是 Comet 内部记账）
    function balanceOf(address owner) external view returns (uint256);

    function baseToken() external view returns (address);
    function baseScale() external view returns (uint256); // 可选：做精度/缩放校验时用
}