//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Vault是不可升级的支持ERC20合约
// 一个Vault是一个新市场
// 策略是可以选择启用或者不启用的, 所以策略需要可插拔
// 这个版本的vault做单资产记账模式, 收回的时候可以根据token奖励做Inkind赎回
import "contracts/Core/Utils/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/Core/Comptroller/IVaultComptroller.sol";
import "contracts/Core/Comptroller/VaultComptroller.sol";
import "contracts/Utils/VaultConfigLib.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Vault is Ownable2Step, ERC20 {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using VaultConfigLib for uint256;

    struct Parameters {
        // bit 0-15 maxStrategyBps
        // bit 16-31 minIdleBps
        // bit 32-47 maxDeployPerTxBps
        // bit 48-63 maxWithdrawPerTxBps
        // bit 64-79 redeemCoolDown seconds
        // bit 80-95 performanceFeeBps
        // bit 96 pauseFlag
        // bit 97 -112  managerFeeBps
        uint256 word;
    }

    Parameters internal parameters;
    address internal immutable FEE_RESERVER;
    address internal immutable DENOMINATION_ASSET;
    address internal immutable COMPTROLLER;
    address internal immutable VAULT_MANAGER;

    uint256 internal constant YEAR_SECONDS = 31_557_600; // 365.25 days

    uint256 internal lastPayoutProtocolFee;
    uint8 internal reentrancyGuard = 1;

    mapping(address => bool) public registriedStrategies;
    mapping(address => uint256) public trackedAssetsIndex; // OFFSET + 1, asset => index, 0 表示不存在

    address[] internal trackedAssets;
    address[] internal strategies;

    event WithdrawTo(address indexed _recipient, address _asset, uint256 _amount);
    event NewTrackedAsset(address _asset);
    event RemovedTrackedAsset(address _asset);
    event MaxStrategyBpsChanged(uint16 _value);
    event MinIdleBpsChanged(uint16 _value);
    event MaxDeployPerTxBpsChanged(uint16 _value);
    event MaxWithdrawPerTxBpsChanged(uint16 _value);
    event RedeemCoolDownSecChanged(uint16 _value);
    event PerformanceFeeBpsChanged(uint16 _value);
    event PauseFlagChanged(bool _value);
    event RegistryStrategy(address _strategy);
    event UnregistryStrategy(address _strategy);
    event DepositFeeRateBpsChanged(uint16 newValue);
    event RedeemFeeRateBpsChanged(uint16 newValue);
    event ManagerFeeBpsChanged(uint16 value);
    event ProtocolFeePaid(uint256 _paidTime, uint256 _amount);
    event ApprovedToStrategy(address indexed _strategy, uint256 _allowance);

    error AssetAlreadyTracked(address _asset);
    error AssetIsNotExist(address _asset);
    error unauthorizedStrategy(address _strategy);

    modifier onlyComptroller() {
        require(msg.sender == COMPTROLLER, "Vault: caller is not the comptroller");
        require(IVaultComptroller(COMPTROLLER).checkReverseMutex(), "Vault: action is not allowed");
        _;
    }

    modifier onlyComptrollerOwner() {
        require(
            msg.sender == IVaultComptroller(COMPTROLLER).getComptrollerOwner(),
            "Vault: caller is not the comptroller owner"
        );
        _;
    }

    modifier whenNotPaused() {
        require(parameters.word.getPauseFlag() == false, "Vault: paused");
        _;
    }

    modifier nonReentrancyGuard() {
        require(reentrancyGuard == 1, "Vault: reentrancy is not allowed");
        reentrancyGuard = 2;
        _;
        reentrancyGuard = 1;
    }

    constructor(
        address _comptroller,
        address _denominationAsset,
        address _vaultManager,
        address _feeReserver,
        uint256 _delay,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        DENOMINATION_ASSET = _denominationAsset;
        VAULT_MANAGER = _vaultManager;
        COMPTROLLER = _comptroller;
        FEE_RESERVER = _feeReserver;
        address owner = IVaultComptroller(COMPTROLLER).getComptrollerOwner();
        __init_Ownable2Step(owner, _delay);
    }

    function mintShare(
        address _account,
        uint256 _amount
    ) external onlyComptroller nonReentrancyGuard whenNotPaused {
        _mint(_account, _amount);
    }

    function burnShare(
        address _account,
        uint256 _amount
    ) external onlyComptroller nonReentrancyGuard whenNotPaused {
        _burn(_account, _amount);
    }

    function withdrawTo(
        address _recipient,
        address _asset,
        uint256 _amount
    ) external onlyComptroller nonReentrancyGuard whenNotPaused {
        IERC20(_asset).safeTransfer(_recipient, _amount);
        emit WithdrawTo(_recipient, _asset, _amount);
    }

    function addTrackedAsset(address _asset) external onlyComptrollerOwner {
        if (trackedAssetsIndex[_asset] != 0) {
            revert AssetAlreadyTracked(_asset);
        }
        trackedAssets.push(_asset);
        trackedAssetsIndex[_asset] = trackedAssets.length;
        emit NewTrackedAsset(_asset);
    }

    function removeTrackedAsset(address _asset) external onlyComptrollerOwner {
        uint256 index = trackedAssetsIndex[_asset] - 1;
        if (index == 0) {
            revert AssetIsNotExist(_asset);
        }
        address lastAsset = trackedAssets[trackedAssets.length - 1];
        trackedAssets[index] = lastAsset;
        trackedAssets.pop();
        delete trackedAssetsIndex[_asset];
        trackedAssetsIndex[lastAsset] = index + 1;
        emit RemovedTrackedAsset(_asset);
    }

    function registryStreategy(address _strategy) external onlyComptrollerOwner {
        registriedStrategies[_strategy] = true;
        strategies.push(_strategy);
        emit RegistryStrategy(_strategy);
    }

    function unregistryStreategy(address _strategy) external onlyComptrollerOwner {
        registriedStrategies[_strategy] = false;
        emit UnregistryStrategy(_strategy);
    }

    function isRegistryStrategy(address _strategy) public view returns (bool) {
        return registriedStrategies[_strategy];
    }

    // ===== Governance =====

    function setMaxStrategyBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setMaxStrategyBps(value);
        emit MaxStrategyBpsChanged(value);
    }

    function setMinIdleBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setMinIdleBps(value);
        emit MinIdleBpsChanged(value);
    }

    function setMaxDeployPerTxBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setMaxDeployPerTxBps(value);
        emit MaxDeployPerTxBpsChanged(value);
    }

    function setMaxWithdrawPerTxBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setMaxWithdrawPerTxBps(value);
        emit MaxWithdrawPerTxBpsChanged(value);
    }

    function setRedeemCoolDownSec(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setRedeemCoolDownSec(value);
        emit RedeemCoolDownSecChanged(value);
    }

    function setPerformanceFeeBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setPerformanceFeeBps(value);
        emit PerformanceFeeBpsChanged(value);
    }

    function setPauseFlag(bool on) external onlyComptrollerOwner {
        parameters.word = parameters.word._setPauseFlag(on);
        emit PauseFlagChanged(on);
    }

    function setManagerFeeBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setManagerFeeBps(value);
        emit ManagerFeeBpsChanged(value);
    }

    function setDepositFeeRateBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setDepositFeeRateBps(value);
        emit DepositFeeRateBpsChanged(value);
    }

    function setRedeemFeeRateBps(uint16 value) external onlyComptrollerOwner {
        parameters.word = parameters.word._setRedeemFeeRateBps(value);
        emit RedeemFeeRateBpsChanged(value);
    }

    function approveToStrategy(
        address _strategy,
        uint256 _allowance
    ) external onlyComptroller nonReentrancyGuard {
        if (!isRegistryStrategy(_strategy)) {
            revert unauthorizedStrategy(_strategy);
        }
        IERC20(DENOMINATION_ASSET).approve(_strategy, 0);
        IERC20(DENOMINATION_ASSET).approve(_strategy, _allowance);
        emit ApprovedToStrategy(_strategy, _allowance);
    }

    // ============

    function payProtocolFee()
        external
        onlyComptroller
        nonReentrancyGuard
        whenNotPaused
        returns (uint256)
    {
        uint256 timeDiff = block.timestamp - lastPayoutProtocolFee;
        if (timeDiff == 0) {
            return 0;
        }
        uint16 feeBps = parameters.word.getManagerFeeBps();
        // fee = totalShares * rate / BPS * timeDiff / YEAR_SECONDS
        // fee = totalShares * rate * timeDiff / YEAR_SECONDS / BPS
        uint256 totalShares = totalSupply();
        uint256 fee = totalShares.mulDiv(feeBps * timeDiff, YEAR_SECONDS);
        fee = fee.mulDiv(1, 10_000, Math.Rounding.Ceil);
        lastPayoutProtocolFee = block.timestamp;
        _mint(FEE_RESERVER, fee);
        emit ProtocolFeePaid(lastPayoutProtocolFee, fee);
        return fee;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    // ======= Getter =====

    function getTrackedAssets() external view returns (address[] memory) {
        return trackedAssets;
    }

    function getDenominationAsset() external view returns (address) {
        return DENOMINATION_ASSET;
    }

    function getComptroller() external view returns (address) {
        return COMPTROLLER;
    }

    function getFeeReserver() external view returns (address) {
        return FEE_RESERVER;
    }

    function getLastPayoutProtocolFee() external view returns (uint256) {
        return lastPayoutProtocolFee;
    }

    function getVaultConfig() external view returns (uint256) {
        return parameters.word;
    }

    function getVaultManager() external view returns (address) {
        return VAULT_MANAGER;
    }

    function getStrategies() external view returns (address[] memory) {
        return strategies;
    }
}
