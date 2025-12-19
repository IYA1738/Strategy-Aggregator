//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Core/Vault/IVault.sol";
import "contracts/Fee-Manager/IFeeManager.sol";
import "contracts/Infrastructure/ValueCalculator.sol";
import "contracts/Core/Utils/Ownable2Step.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "contracts/External-Interface/IWETH.sol";
import "contracts/Fee-Manager/IFeeManager.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 资金流向是始终从vault直入直出 但是必须经过Comptroller来控制， 在反向锁的受控流程中

contract VaultComptroller is Ownable2Step {
    using Math for uint256;
    using SafeERC20 for IERC20;

    bool internal reverseMutex;
    bool internal reentrancyGuard;

    address internal immutable WETH;
    address internal immutable FEE_MANAGER;
    address internal immutable VALUE_CALCULATOR;
    mapping(address => bool) public isTrackedVault;

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

    error VaultNotTracked(address _vault);
    error BadAmount();

    modifier allowAction() {
        require(!reverseMutex, "VaultComptroller: action is not allowed");
        reverseMutex = true;
        _;
        reverseMutex = false;
    }

    modifier nonReentrancyGuard() {
        require(!reentrancyGuard, "VaultComptroller: reentrancy is not allowed");
        reentrancyGuard = true;
        _;
        reentrancyGuard = false;
    }

    constructor(address _weth, address _feeManager, address _valueCalculator) {
        WETH = _weth;
        FEE_MANAGER = _feeManager;
        VALUE_CALCULATOR = _valueCalculator;
    }

    function checkReverseMutex() external view returns (bool) {
        return reverseMutex;
    }

    // ===== user interaction =====

    function deposit(address _vault, uint256 _amount) external nonReentrancyGuard {
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

        uint256 preChargeFeeBalance = IERC20(denominationAsset).balanceOf(msg.sender);
        IFeeManager(FEE_MANAGER).invokeHook(
            IFeeManager.FeeType.DEPOSIT,
            abi.encode(_vault, msg.sender, _amount)
        );
        uint256 postChargeFeeBalance = IERC20(denominationAsset).balanceOf(msg.sender);

        uint256 fee = postChargeFeeBalance - preChargeFeeBalance; //不会小于0 不存在收费后余额大于收费前余额

        uint256 actualAmount = _amount - fee;

        if (denominationAsset != WETH) {
            IERC20(denominationAsset).safeTransferFrom(msg.sender, _vault, actualAmount);
        } else {
            IERC20(WETH).safeTransfer(_vault, actualAmount);
        }

        uint256 nav = 100000; //ValueCalculator(VALUE_CALCULATOR).calcNav(_vault); 先测试一下

        // uint256 scale = 10 ** (18 - IERC20(denominationAsset).decimals());

        uint256 totalSupply = IERC20(_vault).totalSupply();

        // Shares / Supply = (amount / NAV)
        // Shares = Supply * amount / NAV
        if (totalSupply == 0) {
            return (actualAmount, fee);
        }
        uint256 sharesToMint = actualAmount.mulDiv(totalSupply, nav, Math.Rounding.Floor);

        return (sharesToMint, fee);
    }

    function redeemInKind(
        address _recipient,
        address _vault,
        uint256 _sharesQuantity
    ) external nonReentrancyGuard {
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
        } else if (postFeesRedeemerSharesBalance >= preFeesRedeemerSharesBalance) {
            sharesToRedeem_ -= postFeesRedeemerSharesBalance - preFeesRedeemerSharesBalance;
        } //不存在扣完费后还大于等于的情况

        IVault(_vault).burnShare(msg.sender, sharesToRedeem_);

        return (sharesToRedeem_, shareSupply);
    }

    function _preRedeemInKindHook(
        address _vault,
        address _redeemer,
        uint256 _shareToRedeem
    ) private {
        IVault(_vault).payProtocolFee();
        try
            IFeeManager(getFeeManager()).invokeHook(
                IFeeManager.FeeType.REDEEM,
                abi.encode(_vault, _redeemer, _shareToRedeem)
            )
        {} // emit这次错误 官方承担Fee Manager问题导致的没收到这次手续费 // 考虑用户体验 因此不应该协议没有收到费用就导致提现失败 // Catch Fee Manager revert， 因为不回滚所有状态
        catch (bytes memory err) {
            emit PreRedeemInKindHookFailed(err, _redeemer, _shareToRedeem);
        }
    }

    // ===== Interaction with strategies =====

    function interactWithStrategy(
        IStrategyBase.ActionType _action,
        address _vault,
        address _strategy,
        bytes calldata _data
    ) external nonReentrancyGuard {
        require(
            _validateManagerAction(_vault, _strategy),
            "VaultComptroller: caller is not the vault manager"
        );
        IStrategyBase(_strategy).receiveActionFromComptroller(_action, _vault, _data);
        emit StrategyInteraction(_vault, _strategy, _action, _data);
    }

    function _validateManagerAction(
        address _vault,
        address _strategy
    ) internal view returns (bool) {
        bool isVaultManager = IVault(_vault).getVaultManager() == address(this);
        bool isRegistryStrategy = IVault(_vault).isRegistryStrategy(_strategy);
        bool isRegistryVault = isTrackedVault[_vault];
        return isVaultManager && isRegistryStrategy && isRegistryVault;
    }

    function getComptrollerOwner() public view returns (address) {
        return super.getOwner();
    }

    function getFeeManager() public view returns (address) {
        return FEE_MANAGER;
    }

    receive() external payable {
        if (msg.value > 0) {
            IWETH(WETH).deposit();
            //deposit();
        }
    }
}
