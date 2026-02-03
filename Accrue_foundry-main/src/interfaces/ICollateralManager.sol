// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICollateralManager
/// @notice Interface for managing collateral positions
interface ICollateralManager {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed vault, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed vault, uint256 amount);
    event CollateralConfigUpdated(
        address indexed vault, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus
    );
    event CollateralSeized(address indexed user, address indexed vault, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Configuration for each collateral type
    struct CollateralConfig {
        bool isActive; // Whether this collateral is accepted
        uint256 ltv; // Loan-to-Value ratio (e.g., 6000 = 60%)
        uint256 liquidationThreshold; // Threshold for liquidation (e.g., 7500 = 75%)
        uint256 liquidationBonus; // Bonus for liquidators (e.g., 500 = 5%)
        uint256 decimals; // Token decimals
    }

    /// @notice User's collateral position
    struct CollateralPosition {
        uint256 amount; // Amount of collateral deposited
    }

    /*//////////////////////////////////////////////////////////////
                         COLLATERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit collateral
    /// @param vault The PositionVault address
    /// @param amount The amount to deposit
    function depositCollateral(address vault, uint256 amount) external;

    /// @notice Withdraw collateral (must maintain health factor > 1)
    /// @param vault The PositionVault address
    /// @param amount The amount to withdraw
    function withdrawCollateral(address vault, uint256 amount) external;

    /// @notice Get user's collateral amount for a specific vault
    /// @param user The user address
    /// @param vault The vault address
    /// @return The collateral amount
    function getCollateralAmount(address user, address vault) external view returns (uint256);

    /// @notice Get all collateral vaults for a user
    /// @param user The user address
    /// @return vaults Array of vault addresses
    /// @return amounts Array of collateral amounts
    function getUserCollaterals(address user) external view returns (address[] memory vaults, uint256[] memory amounts);

    /*//////////////////////////////////////////////////////////////
                           VALUE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get total collateral value in USD for a user
    /// @param user The user address
    /// @return The total collateral value (8 decimals, USD)
    function getTotalCollateralValue(address user) external view returns (uint256);

    /// @notice Get total collateral value adjusted by LTV
    /// @param user The user address
    /// @return The LTV-adjusted collateral value (8 decimals, USD)
    function getAdjustedCollateralValue(address user) external view returns (uint256);

    /// @notice Get maximum borrowable amount for a user
    /// @param user The user address
    /// @return The maximum borrow amount in USDC (6 decimals)
    function getMaxBorrowAmount(address user) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            HEALTH FACTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate health factor for a user
    /// @param user The user address
    /// @return The health factor (18 decimals, < 1e18 means liquidatable)
    function getHealthFactor(address user) external view returns (uint256);

    /// @notice Check if a user can be liquidated
    /// @param user The user address
    /// @return True if health factor < 1
    function isLiquidatable(address user) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION SUPPORT
    //////////////////////////////////////////////////////////////*/

    /// @notice Seize collateral during liquidation (only callable by LiquidationEngine)
    /// @param user The user being liquidated
    /// @param vault The collateral vault
    /// @param amount The amount to seize
    function seizeCollateral(address user, address vault, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                              ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Set collateral configuration
    /// @param vault The vault address
    /// @param ltv Loan-to-Value ratio (basis points)
    /// @param liquidationThreshold Liquidation threshold (basis points)
    /// @param liquidationBonus Liquidation bonus (basis points)
    function setCollateralConfig(address vault, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus)
        external;

    /// @notice Get collateral configuration
    /// @param vault The vault address
    /// @return The collateral configuration
    function getCollateralConfig(address vault) external view returns (CollateralConfig memory);
}
