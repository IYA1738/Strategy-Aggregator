//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IStrategyBase{
    enum ActionType {
        DEPLOY_FUND,
        HARVEST_FUND
    }

    function receiveActionFromComptroller(ActionType _action, address _vault, bytes calldata _data) external;
}