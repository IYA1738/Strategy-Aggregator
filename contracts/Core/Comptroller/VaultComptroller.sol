//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Core/Vault/IVault.sol";
import "contracts/Fee-Manager/IFeeManager.sol";
import "contracts/Infrastructure/ValueCalculator.sol";
import "contracts/Core/Utils/Ownable2Step.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "contracts/External-Interface/IWETH.sol";
import "contracts/Fee-Manager/IFeeManager.sol";
import "contracts/Utils/WadMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// 资金流向是始终从vault直入直出 但是必须经过Comptroller来控制， 在反向锁的受控流程中

contract VaultComptroller is Ownable2Step {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using WadMath for uint256;

    bool private reverseMutex;

    uint8 private reentrancyStatus;
    uint8 private constant REENTRANCY_NOT_ENTERED = 1;
    uint8 private constant REENTRANCY_ENTERED = 2;

    address internal immutable FEE_RESERVER;
    address internal immutable WETH;
    address internal immutable FEE_MANAGER;
    address internal immutable VALUE_CALCULATOR;
    mapping(address => bool) public isTrackedVault;

    uint256 internal constant WAD = 1e18;
    uint256 constant VIRTUAL_SHARES = 1e18;
    uint256 constant VIRTUAL_ASSETS = 1e18;

    event Deposited(
        address indexed _vault,
        address indexed _user,
        address _asset,
        uint256 _fee,
        uint256 _amount
    );
    event RedeemInkind(
        address indexed _caller,
        address indexed _recipient,
        address indexed _vault,
        address[] _payoutAssets,
        uint256[] _payoutAmounts
    );
    event StrategyInteraction(
        address indexed _vault,
        address indexed _strategy,
        IStrategyBase.ActionType _action,
        bytes _data
    );
    event PreRedeemInKindHookFailed(bytes _err, address indexed _redeemer, uint256 _shareToRedeem);
    event AddTrackedVault(address _vault);
    event RemoveTrackedVault(address _vault);

    error VaultNotTracked(address _vault);
    error BadAmount();
    error ReentrancyLock();

    // 反向锁check 带这个modifier的函数才有权操作vault
    modifier allowAction() {
        require(!reverseMutex, "VaultComptroller: action is not allowed");
        reverseMutex = true;
        _;
        reverseMutex = false;
    }

    function _checkReentrancy() private view {
        if (reentrancyStatus == REENTRANCY_ENTERED) {
            revert ReentrancyLock();
        }
    }

    modifier nonReentrancyGuard() {
        _checkReentrancy();
        reentrancyStatus = REENTRANCY_ENTERED;
        _;
        reentrancyStatus = REENTRANCY_NOT_ENTERED;
    }

    constructor(
        address _weth,
        address _feeManager,
        address _valueCalculator,
        address _feeReserver
    ) {
        WETH = _weth;
        FEE_MANAGER = _feeManager;
        VALUE_CALCULATOR = _valueCalculator;
        FEE_RESERVER = _feeReserver;
        __init_Ownable2Step(msg.sender, 0);
        reentrancyStatus = REENTRANCY_NOT_ENTERED;
    }

    function checkReverseMutex() external view returns (bool) {
        return reverseMutex;
    }

    // ===== user interaction =====

    function deposit(address _vault, uint256 _amount) external nonReentrancyGuard allowAction {
        if (!isTrackedVault[_vault]) {
            revert VaultNotTracked(_vault);
        }
        if (_amount == 0) {
            revert BadAmount();
        }

        (uint256 sharesToMint, uint256 fee) = _preDepositHook(_vault, _amount);

        IVault(_vault).mintShare(msg.sender, sharesToMint);

        emit Deposited(_vault, msg.sender, IVault(_vault).getDenominationAsset(), fee, _amount);
    }

    function _preDepositHook(address _vault, uint256 _amount) private returns (uint256, uint256) {
        address denominationAsset = IVault(_vault).getDenominationAsset();
        if (_amount == 0) revert BadAmount();

        uint256 preSupply = IERC20(_vault).totalSupply();
        uint256 preNavWad = ValueCalculator(VALUE_CALCULATOR).calcNav(_vault); // 返回 1e18(WAD)

        uint256 fee = IFeeManager(FEE_MANAGER).invokeHook(
            IFeeManager.FeeType.DEPOSIT,
            abi.encode(_vault, _amount)
        );

        uint256 actualAmountToken = _amount - fee; // token 原始单位

        uint8 dec = IERC20Metadata(denominationAsset).decimals();
        uint256 actualAmountWad = _toWad(actualAmountToken, dec);

        if (denominationAsset != WETH) {
            IERC20(denominationAsset).safeTransferFrom(msg.sender, _vault, actualAmountToken);
        } else {
            IERC20(WETH).safeTransfer(_vault, actualAmountToken);
        }

        uint256 sharesToMint;

        // Shares = amountWad * preSupply / preNavWad
        // （等价于 amount / (NAV/Supply)）
        sharesToMint = actualAmountWad.mulDiv(
            preSupply + VIRTUAL_SHARES,
            preNavWad + VIRTUAL_ASSETS,
            Math.Rounding.Floor
        );
        fee = fee._toWad(IERC20Metadata(denominationAsset).decimals());
        uint256 feeToMint = fee.mulDiv(
            preSupply + VIRTUAL_SHARES,
            preNavWad + VIRTUAL_ASSETS,
            Math.Rounding.Floor
        );
        IVault(_vault).mintShare(FEE_RESERVER, feeToMint);

        return (sharesToMint, fee);
    }

    function redeemInKind(
        address _recipient,
        address _vault,
        uint256 _sharesQuantity
    ) external nonReentrancyGuard allowAction {
        (uint256 sharesToRedeem, uint256 shareSupply) = _preRedeemInKindHookSetUp(
            msg.sender,
            _vault,
            _sharesQuantity
        );
        address[] memory payoutAssets = IVault(_vault).getTrackedAssets();
        uint256 payoutAssetsLen = payoutAssets.length;
        uint256[] memory payoutAmounts = new uint256[](payoutAssetsLen);
        for (uint256 i = 0; i < payoutAssetsLen; ) {
            address asset = payoutAssets[i];
            uint256 balance = IERC20(asset).balanceOf(_vault);
            // payoutAmount / balance = sharesToRedeem / shareSupply
            // payoutAmount = sharesToRedeem * balance / shareSupply
            payoutAmounts[i] = balance.mulDiv(sharesToRedeem, shareSupply, Math.Rounding.Floor);
            IVault(_vault).withdrawTo(_recipient, asset, payoutAmounts[i]);
            unchecked {
                i++;
            }
        }

        emit RedeemInkind(msg.sender, _recipient, _vault, payoutAssets, payoutAmounts);
    }

    function _preRedeemInKindHookSetUp(
        address _redeemer,
        address _vault,
        uint256 _sharesQuantity
    ) private returns (uint256 sharesToRedeem_, uint256 shareSupply_) {
        IVault(_vault).payProtocolFee();
        uint256 shareSupply = IERC20(_vault).totalSupply();
        uint256 preFeesRedeemerSharesBalance = IERC20(_vault).balanceOf(_redeemer);

        if (_sharesQuantity == type(uint256).max) {
            sharesToRedeem_ = preFeesRedeemerSharesBalance;
        } else {
            sharesToRedeem_ = _sharesQuantity;
        }

        _preRedeemInKindHook(_vault, _redeemer, sharesToRedeem_);

        uint256 postFeesRedeemerSharesBalance = IERC20(_vault).balanceOf(_redeemer);

        if (_sharesQuantity == type(uint256).max) {
            sharesToRedeem_ = postFeesRedeemerSharesBalance;
        } else if (postFeesRedeemerSharesBalance <= preFeesRedeemerSharesBalance) {
            sharesToRedeem_ -= preFeesRedeemerSharesBalance - postFeesRedeemerSharesBalance;
        } //不存在扣完费后还大于等于的情况

        IVault(_vault).burnShare(msg.sender, sharesToRedeem_);

        return (sharesToRedeem_, shareSupply);
    }

    function _preRedeemInKindHook(
        address _vault,
        address _redeemer,
        uint256 _shareToRedeem
    ) private {
        uint256 fee = IFeeManager(getFeeManager()).invokeHook(
            IFeeManager.FeeType.REDEEM,
            abi.encode(_vault, _shareToRedeem)
        );
        IVault(_vault).burnShare(_redeemer, fee);
        IVault(_vault).mintShare(FEE_RESERVER, fee);
    }

    // ===== Interaction with strategies =====

    function interactWithStrategy(
        IStrategyBase.ActionType _action,
        address _vault,
        address _strategy,
        uint256 _allowance,
        bytes calldata _data
    ) external allowAction nonReentrancyGuard {
        require(
            _validateManagerAction(_vault, _strategy),
            "VaultComptroller: caller is not the vault manager"
        );
        if (_action == IStrategyBase.ActionType.DEPLOY_FUND) {
            IVault(_vault).approveToStrategy(_strategy, _allowance);
        }
        IStrategyBase(_strategy).receiveActionFromComptroller(_action, _vault, _data);
        emit StrategyInteraction(_vault, _strategy, _action, _data);
    }

    function _validateManagerAction(
        address _vault,
        address _strategy
    ) internal view returns (bool) {
        bool isVaultManager = IVault(_vault).getVaultManager() == msg.sender;
        bool isRegistryStrategy = IVault(_vault).isRegistryStrategy(_strategy);
        bool isRegistryVault = isTrackedVault[_vault];
        return isVaultManager && isRegistryStrategy && isRegistryVault;
    }

    function getComptrollerOwner() public view returns (address) {
        return getOwner();
    }

    function getFeeManager() public view returns (address) {
        return FEE_MANAGER;
    }

    function addTrackedVault(address _vault) external onlyOwner {
        isTrackedVault[_vault] = true;
        emit AddTrackedVault(_vault);
    }

    function removeTrackedVault(address _vault) external onlyOwner {
        isTrackedVault[_vault] = false;
        emit RemoveTrackedVault(_vault);
    }

    function _toWad(uint256 _amountRaw, uint8 _tokenDecimals) internal pure returns (uint256) {
        if (_tokenDecimals == 18) {
            return _amountRaw;
        } else if (_tokenDecimals < 18) {
            return _amountRaw * 10 ** (18 - _tokenDecimals);
        } else {
            uint256 scale = 10 ** (_tokenDecimals - 18);
            return _amountRaw / scale; //必定整除不会丢失精度
        }
    }

    receive() external payable {
        if (msg.value > 0) {
            IWETH(WETH).deposit();
            //deposit();
        }
    }
}
