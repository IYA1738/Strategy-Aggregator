//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

abstract contract Ownable2Step {
    address internal owner;
    address internal pendingOwner;
    uint256 internal executableTime;
    uint256 internal DELAY;

    bool internal isInitialized;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 executableTime
    );
    event OwnershipAccepted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferredCancelled(address indexed previousOwner, address indexed newOwner);

    modifier onlyInitializing() {
        require(!isInitialized, "Ownable: contract is already initialized");
        _;
        isInitialized = true;
    }

    function __init_Ownable2Step(address _owner, uint256 _DELAY) public onlyInitializing {
        owner = _owner;
        DELAY = _DELAY;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0) && _newOwner != owner, "Ownable: Invalid new owner");
        _transferOwnership(_newOwner);
    }

    function acceptOwnership() external {
        require(
            block.timestamp >= executableTime && executableTime != 0,
            "Ownable: ownership not ready"
        );
        require(msg.sender == pendingOwner, "Ownable: caller is not the pending owner");
        _acceptOwnership();
    }

    function cancelOwnershipTransfer() external onlyOwner {
        address oldPending = pendingOwner;
        require(oldPending != address(0), "Ownable: no pending owner");
        pendingOwner = address(0);
        executableTime = 0;
        emit OwnershipTransferredCancelled(owner, oldPending);
    }

    function _transferOwnership(address _newOwner) private {
        pendingOwner = _newOwner;
        executableTime = block.timestamp + DELAY;
        emit OwnershipTransferred(owner, pendingOwner, executableTime);
    }

    function _acceptOwnership() private {
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        executableTime = 0;
        emit OwnershipAccepted(previousOwner, owner);
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getPendingOwner() public view returns (address) {
        return pendingOwner;
    }

    function getDelay() public view returns (uint256) {
        return DELAY;
    }

    function getExecutableTime() public view returns (uint256) {
        return executableTime;
    }
}
