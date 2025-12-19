//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

abstract contract StrategyBaseLayout{

    bytes32 internal constant STATE_SLOT = bytes32(uint256(keccak256("IYA.strategy.state.storage")) - 1);
    bytes32 internal constant CONFIG_SLOT = bytes32(uint256(keccak256("IYA.strategy.config.storage")) - 1);

   struct StrategyStateStorage{
       address targetProtocol;
       address manager;
       mapping(address => bool) allowedVaults;
   }

   struct StrategyConfig{
       uint256 config;
   }

   function getStateSlot() internal pure returns(StrategyStateStorage storage $state){
        bytes32 slot = STATE_SLOT;
        assembly{
            $state.slot := slot
        }
   }

   function getConfigSlot() internal pure returns(StrategyConfig storage $config){
     bytes32 slot = CONFIG_SLOT;
        assembly{
            $config.slot := slot
        }
   }

}