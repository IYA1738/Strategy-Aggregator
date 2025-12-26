//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase.t.sol";
import "contracts/Strategies/CompoundV3LenderUSDC.sol";
import "contracts/External-Interface/ICompoundCometMinimum.sol";
import "forge-std/console2.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "contracts/Strategies/AaveV3LenderUSDC.sol";
import "contracts/External-Interface/IAaveProtocolDataProvider.sol";

contract VaultTestBase2 is VaultTestBase {
    address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_DATA_PROVIDER = 0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A;
    AaveV3LenderUSDC aaveV3LenderUSDC;

    CompoundV3LenderUSDC compoundV3LenderUSDC;
    address constant Comet = 0xb125E6687d4313864e53df431d5425969c15Eb2F; // Base mainnet USDC Comet
    address constant Rewards = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(deployer);
        aaveV3LenderUSDC = new AaveV3LenderUSDC(
            address(comptroller),
            AAVE_V3_POOL,
            AAVE_DATA_PROVIDER,
            address(agg),
            USDC
        );
        aaveV3LenderUSDC.setManager(deployer);
        vault.registryStreategy(address(aaveV3LenderUSDC));
        aaveV3LenderUSDC.setAllowedVault(address(vault), true);

        compoundV3LenderUSDC = new CompoundV3LenderUSDC(
            address(comptroller),
            Comet,
            Rewards,
            address(agg),
            USDC
        );
        compoundV3LenderUSDC.setManager(deployer);
        vault.registryStreategy(address(compoundV3LenderUSDC));
        compoundV3LenderUSDC.setAllowedVault(address(vault), true);
        vm.stopPrank();
    }
}
