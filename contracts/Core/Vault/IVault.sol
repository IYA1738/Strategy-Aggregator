//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IVault {
    function mintShare(address _recipient, uint256 _amount) external;

    function burnShare(address _account, uint256 _amount) external;

    function getDenominationAsset() external view returns (address);

    function getTrackedAssets() external view returns (address[] memory);

    function withdrawTo(address _recipient, address asset, uint256 _amount) external;

    function getVaultManager() external view returns (address);

    function isRegistryStrategy(address _strategy) external view returns (bool);

    function payProtocolFee() external;

    function getVaultConfig() external view returns (uint256);

    function approveToStrategy(address _strategy, uint256 _allowance) external;

    function getStrategies() external view returns (address[] memory);
}
