// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IInterestRateModel
/// @notice Interface for interest rate calculation
interface IInterestRateModel {
    /// @notice Calculate the borrow rate based on utilization
    /// @param utilizationRate The current utilization rate (18 decimals)
    /// @return The borrow rate per second (18 decimals)
    function getBorrowRate(uint256 utilizationRate) external view returns (uint256);

    /// @notice Calculate the deposit rate based on utilization
    /// @param utilizationRate The current utilization rate (18 decimals)
    /// @return The deposit rate per second (18 decimals)
    function getDepositRate(uint256 utilizationRate) external view returns (uint256);

    /// @notice Calculate both rates at once
    /// @param utilizationRate The current utilization rate
    /// @return borrowRate The borrow rate per second
    /// @return depositRate The deposit rate per second
    function getRates(uint256 utilizationRate) external view returns (uint256 borrowRate, uint256 depositRate);

    /// @notice Get the optimal utilization rate
    /// @return The optimal utilization (18 decimals)
    function optimalUtilization() external view returns (uint256);

    /// @notice Get the base rate
    /// @return The base rate per second (18 decimals)
    function baseRate() external view returns (uint256);

    /// @notice Get slope 1 (rate increase below optimal utilization)
    /// @return The slope 1 value
    function slope1() external view returns (uint256);

    /// @notice Get slope 2 (rate increase above optimal utilization)
    /// @return The slope 2 value
    function slope2() external view returns (uint256);
}
