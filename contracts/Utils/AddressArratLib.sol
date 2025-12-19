//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library AddressArrayLib {
    function removeStorageItem(address[] storage _arr, uint256 _index) internal {}

    function isContain(address[] calldata _arr, address _addr) internal pure returns (bool) {
        uint256 length = _arr.length;
        for (uint256 i = 0; i < length; ) {
            if (_arr[i] == _addr) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }
}
