// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PercentageMath
/// @notice Math library for percentage calculations with basis points (1 bp = 0.01%)
/// @dev Based on Aave's PercentageMath
library PercentageMath {
    /// @notice 100% in basis points
    uint256 internal constant PERCENTAGE_FACTOR = 1e4; // 10000 = 100%

    /// @notice Half of 100%, used for rounding
    uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

    /// @notice Executes a percentage multiplication
    /// @param value The value to multiply
    /// @param percentage The percentage (in basis points)
    /// @return result = value * percentage / 10000, rounded half up
    function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }
            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }

    /// @notice Executes a percentage division
    /// @param value The value to divide
    /// @param percentage The percentage (in basis points)
    /// @return result = value * 10000 / percentage, rounded half up
    function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        assembly {
            if or(
                iszero(percentage), iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
            ) { revert(0, 0) }
            result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
        }
    }
}
