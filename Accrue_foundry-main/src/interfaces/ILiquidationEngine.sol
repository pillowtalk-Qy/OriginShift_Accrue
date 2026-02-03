// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ILiquidationEngine
/// @notice Interface for the liquidation engine
interface ILiquidationEngine {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        address indexed collateralVault,
        uint256 debtRepaid,
        uint256 collateralSeized
    );

    /*//////////////////////////////////////////////////////////////
                         LIQUIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Liquidate an undercollateralized position
    /// @param borrower The address of the borrower to liquidate
    /// @param collateralVault The collateral vault to seize from
    /// @param debtToRepay The amount of debt to repay
    /// @return collateralSeized The amount of collateral seized
    function liquidate(address borrower, address collateralVault, uint256 debtToRepay)
        external
        returns (uint256 collateralSeized);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get liquidation information for a borrower
    /// @param borrower The borrower address
    /// @param collateralVault The collateral vault
    /// @return maxDebtToRepay Maximum debt that can be repaid
    /// @return collateralToReceive Collateral that would be received
    function getLiquidationInfo(address borrower, address collateralVault)
        external
        view
        returns (uint256 maxDebtToRepay, uint256 collateralToReceive);

    /// @notice Calculate collateral to seize for a given debt amount
    /// @param collateralVault The collateral vault
    /// @param debtToRepay The debt amount to repay
    /// @return The amount of collateral to seize
    function calculateCollateralToSeize(address collateralVault, uint256 debtToRepay)
        external
        view
        returns (uint256);

    /// @notice Check if a position can be liquidated
    /// @param borrower The borrower address
    /// @return True if the position is liquidatable
    function canLiquidate(address borrower) external view returns (bool);

    /// @notice Get the close factor (max % of debt that can be repaid in one liquidation)
    /// @return The close factor (basis points, e.g., 5000 = 50%)
    function closeFactor() external view returns (uint256);

    /// @notice Get the liquidation bonus for a collateral
    /// @param collateralVault The collateral vault
    /// @return The liquidation bonus (basis points)
    function getLiquidationBonus(address collateralVault) external view returns (uint256);
}
