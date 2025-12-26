//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Core/Vault/Vault.sol";
import "contracts/Core/Utils/Ownable2Step.sol";

contract VaultFactory is Ownable2Step {
    event VaultCreated(address vault);

    constructor() {
        __init_Ownable2Step(msg.sender, 0);
    }

    function createVault(
        address _comptroller,
        address _denominationAsset,
        address _vaultManager,
        address _feeReserver,
        uint256 _delay,
        string memory _name,
        string memory _symbol
    ) external onlyOwner returns (address vault_) {
        vault_ = address(
            new Vault(
                _comptroller,
                _denominationAsset,
                _vaultManager,
                _feeReserver,
                _delay,
                _name,
                _symbol
            )
        );
        emit VaultCreated(vault_);
    }
}
