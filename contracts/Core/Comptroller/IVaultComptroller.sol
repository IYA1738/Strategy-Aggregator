//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Strategies/Base/IStrategyBase.sol";

interface IVaultComptroller {
    function getComptrollerOwner() external view returns (address);

    function checkReverseMutex() external view returns (bool);

    function interactWithStrategy(
        IStrategyBase.ActionType _action,
        address _vault,
        address _strategy,
        uint256 _allowance,
        bytes calldata _data
    ) external;
}
