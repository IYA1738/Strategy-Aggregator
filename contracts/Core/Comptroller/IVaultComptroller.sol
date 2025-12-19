//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IVaultComptroller{
    function getComptrollerOwner() external view returns(address);

    function checkReverseMutex() external view returns(bool);
}