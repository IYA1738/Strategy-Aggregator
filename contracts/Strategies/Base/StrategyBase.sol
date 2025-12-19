//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/Strategies/Base/IStrategyBase.sol";
import "contracts/Core/Comptroller/IVaultComptroller.sol";
import "contracts/Strategies/Base/StrategyBaseLayout.sol";

abstract contract StrategyBase is StrategyBaseLayout, IStrategyBase {
    address internal immutable COMPTROLLER;

    event TargetProtocolChanged(address prevTargetProtocol, address targetProtocol);
    event ManagerChanged(address prevManager, address manager);

    error InvalidAction();

    // 谁是comptroller的owner 谁就是strategy的owner，就可以操作配置
    // strategy不给owner
    modifier onlyComptrollerOwner() {
        require(
            msg.sender == IVaultComptroller(COMPTROLLER).getComptrollerOwner(),
            "StrategyBase: caller is not the comptroller owner"
        );
        _;
    }

    modifier onlyManager() {
        require(msg.sender == getStateSlot().manager, "StrategyBase: caller is not the manager");
        _;
    }

    function receiveActionFromComptroller(
        ActionType _action,
        address _vault,
        bytes calldata _data
    ) external {
        require(_validateComptrollerCall(_vault), "StrategyBase: Invalid Call");

        if (_action == ActionType.DEPLOY_FUND) {
            handleDeployFund(_vault, _data);
        } else if (_action == ActionType.HARVEST_FUND) {
            handleHarvestFund(_vault, _data);
        } else {
            revert InvalidAction();
        }
    } //接收call、 分发Action和鉴权

    function handleDeployFund(address _vault, bytes calldata _data) internal virtual {}

    function handleHarvestFund(address _vault, bytes calldata _data) internal virtual {}

    function _validateComptrollerCall(address _vault) internal view returns (bool) {
        if (msg.sender != COMPTROLLER) {
            return false;
        }
        if (!isAllowedVault(_vault)) {
            return false;
        }
        return true;
    }

    function setTargetProtocol(address _targetProtocol) external onlyComptrollerOwner {
        address prevTargetProtocol = getStateSlot().targetProtocol;
        getStateSlot().targetProtocol = _targetProtocol;
        emit TargetProtocolChanged(prevTargetProtocol, _targetProtocol);
    }

    function setManager(address _manager) external onlyComptrollerOwner {
        address prevManager = getStateSlot().manager;
        getStateSlot().manager = _manager;
        emit ManagerChanged(prevManager, _manager);
    }

    function isAllowedVault(address _vault) public view returns (bool) {
        return getStateSlot().allowedVaults[_vault];
    }
}
