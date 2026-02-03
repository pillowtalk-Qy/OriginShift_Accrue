// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IPriceOracle
/// @notice Interface for price oracle
interface IPriceOracle {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PriceUpdated(address indexed vault, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event PriceInvalidated(address indexed vault);

    /*//////////////////////////////////////////////////////////////
                            PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price of a position vault token
    /// @param vault The position vault address
    /// @return The price in USD (8 decimals, e.g., 60000000 = $0.60)
    function getPrice(address vault) external view returns (uint256);

    /// @notice Get the USD value of a position amount
    /// @param vault The position vault address
    /// @param amount The amount of position tokens (18 decimals)
    /// @return The USD value (8 decimals)
    function getAssetValue(address vault, uint256 amount) external view returns (uint256);

    /// @notice Check if a price is valid and not stale
    /// @param vault The vault address
    /// @return True if the price is valid
    function isPriceValid(address vault) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                              ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the price for a vault (admin only)
    /// @param vault The vault address
    /// @param price The price in USD (8 decimals)
    function setPrice(address vault, uint256 price) external;

    /// @notice Batch set prices (admin only)
    /// @param vaults Array of vault addresses
    /// @param prices Array of prices
    function setPrices(address[] calldata vaults, uint256[] calldata prices) external;

    /// @notice Invalidate a price (admin only)
    /// @param vault The vault address
    function invalidatePrice(address vault) external;

    /// @notice Set the maximum staleness period (admin only)
    /// @param newMaxStaleness New staleness period in seconds
    function setMaxStaleness(uint256 newMaxStaleness) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price decimals
    /// @return The number of decimals (8)
    function decimals() external pure returns (uint8);

    /// @notice Get the maximum staleness period
    /// @return The max staleness in seconds
    function maxStaleness() external view returns (uint256);

    /// @notice Get price data for a vault
    /// @param vault The vault address
    /// @return price The price
    /// @return lastUpdated The last update timestamp
    /// @return isValid Whether the price is valid
    function getPriceData(address vault) external view returns (uint256 price, uint256 lastUpdated, bool isValid);
}
