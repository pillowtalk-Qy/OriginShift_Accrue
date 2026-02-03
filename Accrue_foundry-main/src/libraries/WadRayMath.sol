// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title WadRayMath
/// @notice Math library for wad (18 decimals) and ray (27 decimals) arithmetic
/// @dev Based on Aave's WadRayMath
library WadRayMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    /// @notice Multiplies two wad numbers, rounding half up
    /// @param a First wad number
    /// @param b Second wad number
    /// @return c = a * b in wad
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // Check overflow
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) { revert(0, 0) }
            c := div(add(mul(a, b), HALF_WAD), WAD)
        }
    }

    /// @notice Divides two wad numbers, rounding half up
    /// @param a Numerator wad
    /// @param b Denominator wad
    /// @return c = a / b in wad
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) { revert(0, 0) }
            c := div(add(mul(a, WAD), div(b, 2)), b)
        }
    }

    /// @notice Multiplies two ray numbers, rounding half up
    /// @param a First ray number
    /// @param b Second ray number
    /// @return c = a * b in ray
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) { revert(0, 0) }
            c := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    /// @notice Divides two ray numbers, rounding half up
    /// @param a Numerator ray
    /// @param b Denominator ray
    /// @return c = a / b in ray
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) { revert(0, 0) }
            c := div(add(mul(a, RAY), div(b, 2)), b)
        }
    }

    /// @notice Converts ray to wad (27 decimals to 18 decimals)
    /// @param a Ray value
    /// @return Wad value
    function rayToWad(uint256 a) internal pure returns (uint256) {
        uint256 halfRatio = WAD_RAY_RATIO / 2;
        uint256 result = halfRatio + a;
        assembly {
            if lt(result, halfRatio) { revert(0, 0) }
        }
        return result / WAD_RAY_RATIO;
    }

    /// @notice Converts wad to ray (18 decimals to 27 decimals)
    /// @param a Wad value
    /// @return b Ray value
    function wadToRay(uint256 a) internal pure returns (uint256 b) {
        assembly {
            b := mul(a, WAD_RAY_RATIO)
            if iszero(eq(div(b, WAD_RAY_RATIO), a)) { revert(0, 0) }
        }
    }
}
