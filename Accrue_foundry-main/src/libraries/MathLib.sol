// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MathLib
/// @notice Common math utilities
library MathLib {
    /// @notice Returns the minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Returns the maximum of two numbers
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /// @notice Safe subtraction that returns 0 if b > a
    function zeroFloorSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }

    /// @notice Multiply and divide with better precision
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @param z The divisor
    /// @return The result of x * y / z
    function mulDiv(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return (x * y) / z;
    }

    /// @notice Multiply and divide with rounding up
    function mulDivUp(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return (x * y + z - 1) / z;
    }

    /// @notice Calculate compound interest
    /// @param principal The principal amount
    /// @param rate The rate per period (in 18 decimals)
    /// @param periods Number of periods
    /// @return The compounded amount
    function compound(uint256 principal, uint256 rate, uint256 periods) internal pure returns (uint256) {
        if (periods == 0) return principal;
        if (rate == 0) return principal;

        // Simple approximation using linear interest for small periods
        // For production, use exponentiation by squaring
        uint256 interest = mulDiv(principal, rate * periods, 1e18);
        return principal + interest;
    }
}
