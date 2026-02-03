// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IPositionVaultFactory
/// @notice Interface for Position Vault Factory
interface IPositionVaultFactory {
    event VaultCreated(uint256 indexed positionId, address indexed vault, string name, string symbol);

    /// @notice Create a new Position Vault
    /// @param positionId The Polymarket position ID
    /// @param name The ERC20 token name
    /// @param symbol The ERC20 token symbol
    /// @return vault The address of the created vault
    function createVault(uint256 positionId, string memory name, string memory symbol)
        external
        returns (address vault);

    /// @notice Get the vault address for a position ID
    /// @param positionId The position ID
    /// @return The vault address (address(0) if not created)
    function getVault(uint256 positionId) external view returns (address);

    /// @notice Get all created vault addresses
    /// @return Array of vault addresses
    function getAllVaults() external view returns (address[] memory);

    /// @notice Get the number of vaults created
    /// @return The vault count
    function getVaultCount() external view returns (uint256);

    /// @notice Get the CTF (Conditional Token Framework) address
    /// @return The CTF contract address
    function ctf() external view returns (address);
}
