//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library WadMath {
    uint256 internal constant WAD = 1e18;

    function _toWad(uint256 _amount, uint8 _dec) internal pure returns (uint256) {
        if (_dec == 18) return _amount;
        else if (_dec < 18) return _amount * (10 ** (18 - _dec));
        else return _amount / (10 ** (_dec - 18));
    }
}
