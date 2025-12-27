//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
interface IFluidFtokenMinimum {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function maxWithdraw(address owner) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);

    function updateRates()
        external
        returns (uint256 tokenExchangePrice, uint256 liquidityExchangePrice);
    function minDeposit() external view returns (uint256);
}
