//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IAaveProtocolDataProvider {
    struct TokenData {
        string symbol;
        address tokenAddress;
    }

    function getReserveTokensAddresses(
        address asset
    )
        external
        view
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        );

    function getATokenTotalSupply(address asset) external view returns (uint256);

    function getTotalDebt(address asset) external view returns (uint256);

    function getUserReserveData(
        address asset,
        address user
    )
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );
}
