// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ILendingPool
/// @notice Interface for the USDC lending pool
interface ILendingPool {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed lender, uint256 amount, uint256 shares);
    event Withdraw(address indexed lender, uint256 amount, uint256 shares);
    event Borrow(address indexed borrower, uint256 amount);
    event Repay(address indexed borrower, uint256 amount);
    event InterestAccrued(uint256 totalDeposits, uint256 totalBorrows, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                           LENDER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit USDC to provide liquidity
    /// @param amount The amount of USDC to deposit
    /// @return shares The amount of pool shares received
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw USDC and earned interest
    /// @param shares The amount of shares to burn
    /// @return amount The amount of USDC withdrawn (principal + interest)
    function withdraw(uint256 shares) external returns (uint256 amount);

    /// @notice Get lender's current balance including accrued interest
    /// @param lender The lender address
    /// @return The total balance (principal + interest)
    function balanceOf(address lender) external view returns (uint256);

    /// @notice Get lender's share balance
    /// @param lender The lender address
    /// @return The share balance
    function sharesOf(address lender) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          BORROWER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrow USDC against deposited collateral
    /// @param amount The amount of USDC to borrow
    function borrow(uint256 amount) external;

    /// @notice Repay borrowed USDC
    /// @param amount The amount to repay (use type(uint256).max for full repay)
    /// @return repaid The actual amount repaid
    function repay(uint256 amount) external returns (uint256 repaid);

    /// @notice Repay on behalf of another borrower
    /// @param borrower The borrower address
    /// @param amount The amount to repay
    /// @return repaid The actual amount repaid
    function repayFor(address borrower, uint256 amount) external returns (uint256 repaid);

    /// @notice Get borrower's current debt including accrued interest
    /// @param borrower The borrower address
    /// @return The total debt (principal + interest)
    function debtOf(address borrower) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current utilization rate
    /// @return The utilization rate (18 decimals, 1e18 = 100%)
    function getUtilizationRate() external view returns (uint256);

    /// @notice Get current interest rates
    /// @return depositRate The deposit APY (18 decimals)
    /// @return borrowRate The borrow APY (18 decimals)
    function getCurrentRates() external view returns (uint256 depositRate, uint256 borrowRate);

    /// @notice Get total deposits in the pool
    function totalDeposits() external view returns (uint256);

    /// @notice Get total borrows from the pool
    function totalBorrows() external view returns (uint256);

    /// @notice Get available liquidity for borrowing
    function availableLiquidity() external view returns (uint256);

    /// @notice Get the underlying asset (USDC)
    function asset() external view returns (address);

    /// @notice Convert shares to assets
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Convert assets to shares
    function convertToShares(uint256 assets) external view returns (uint256);
}
