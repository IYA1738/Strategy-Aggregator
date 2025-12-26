//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

library VaultConfigLib {
    // bit 0-15   maxStrategyBps
    // bit 16-31  minIdleBps
    // bit 32-47  maxDeployPerTxBps
    // bit 48-63  maxWithdrawPerTxBps
    // bit 64-79  redeemCoolDown seconds
    // bit 80-95  performanceFeeBps
    // bit 96     pauseFlag
    // bit 97-112 managerFeeBps
    // bit 113-128 depositFeeRateBps
    // bit 129-144 redeemFeeRateBps

    uint256 constant MAX_STRATEGY_BPS_MASK =
        0x000000000000000000000000000000000000000000000000000000000000FFFF; // bits 0..15
    uint256 constant MIN_IDLE_BPS_MASK =
        0x00000000000000000000000000000000000000000000000000000000FFFF0000; // bits 16..31
    uint256 constant MAX_DEPLOY_PER_TX_MASK =
        0x000000000000000000000000000000000000000000000000FFFF00000000; // bits 32..47
    uint256 constant MAX_WITHDRAW_PER_TX_MASK =
        0x0000000000000000000000000000000000000000FFFF0000000000000000; // bits 48..63
    uint256 constant REDEEM_COOLDOWN_MASK =
        0x000000000000000000000000000000000000FFFF00000000000000000000; // bits 64..79
    uint256 constant PERFORMANCE_FEE_BPS_MASK =
        0x00000000000000000000000000000000FFFF000000000000000000000000; // bits 80..95

    // 1-bit flags
    uint256 constant PAUSE_FLAG_MASK =
        0x0000000000000000000000000000000100000000000000000000000000000000; // bit 96

    uint256 constant MANAGER_FEE_BPS_MASK =
        0x00000000000000000000000000000000000000000000FFFF0000000000000000; // bits 97..112
    uint256 constant DEPOSIT_FEE_RATE_BPS_MASK =
        0x0000000000000000000000000000FFFF00000000000000000000000000000000; // bits 113..128
    uint256 constant REDEEM_FEE_RATE_BPS_MASK =
        0x000000000000000000000000FFFF000000000000000000000000000000000000; // bits 129..144

    function _get16(uint256 cfg, uint256 offset) internal pure returns (uint16) {
        return uint16((cfg >> offset) & 0xFFFF);
    }

    function getMaxStrategyBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 0);
    }

    function getMinIdleBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 16);
    }

    function getMaxDeployPerTxBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 32);
    }

    function getMaxWithdrawPerTxBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 48);
    }

    function getRedeemCoolDownSec(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 64);
    }

    function getPerformanceFeeBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 80);
    }

    function getPauseFlag(uint256 cfg) public pure returns (bool) {
        return (cfg & PAUSE_FLAG_MASK) != 0;
    }

    function getManagerFeeBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 97);
    }

    function getDepositFeeRateBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 113);
    }

    function getRedeemFeeRateBps(uint256 cfg) public pure returns (uint16) {
        return _get16(cfg, 129);
    }

    function _set16(uint256 cfg, uint256 offset, uint16 val) internal pure returns (uint256) {
        uint256 clearMask = ~(uint256(0xFFFF) << offset);
        return (cfg & clearMask) | (uint256(val) << offset);
    }

    function _setMaxStrategyBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 0, v);
    }

    function _setMinIdleBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 16, v);
    }

    function _setMaxDeployPerTxBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 32, v);
    }

    function _setMaxWithdrawPerTxBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 48, v);
    }

    function _setRedeemCoolDownSec(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 64, v);
    }

    function _setPerformanceFeeBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 80, v);
    }

    function _setManagerFeeBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 97, v);
    }

    function _setDepositFeeRateBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 113, v);
    }

    function _setRedeemFeeRateBps(uint256 cfg, uint16 v) internal pure returns (uint256) {
        return _set16(cfg, 129, v);
    }

    function _setPauseFlag(uint256 cfg, bool on) internal pure returns (uint256) {
        return on ? (cfg | PAUSE_FLAG_MASK) : (cfg & ~PAUSE_FLAG_MASK);
    }
}
