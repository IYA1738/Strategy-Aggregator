//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Core/Vault/Vault.sol";

contract VaultFactory {
    event VaultCreated(address vault);

    function createVault(
        address _comptroller,
        address _denominationAsset,
        address _factory,
        uint256 _delay,
        string memory _name,
        string memory _symbol
    ) external returns (address vault_) {
        vault_ = address(
            new Vault(_comptroller, _denominationAsset, _factory, _delay, _name, _symbol)
        );
        emit VaultCreated(vault_);
    }
}
