// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title IPositionVault
/// @notice Interface for Position Vault that wraps ERC1155 to ERC20
interface IPositionVault {
    event Deposit(address indexed sender, address indexed receiver, uint256 amount);
    event Withdraw(address indexed sender, address indexed receiver, uint256 amount);

    /// @notice Deposit ERC1155 Position tokens and receive ERC20 shares
    /// @param amount The amount of Position tokens to deposit
    /// @param receiver The address to receive the shares
    /// @return shares The amount of shares minted (1:1 with assets)
    function deposit(uint256 amount, address receiver) external returns (uint256 shares);

    /// @notice Withdraw ERC1155 Position tokens by burning shares
    /// @param amount The amount of shares to burn
    /// @param receiver The address to receive the Position tokens
    /// @return assets The amount of Position tokens withdrawn
    function withdraw(uint256 amount, address receiver) external returns (uint256 assets);

    /// @notice Returns the total Position tokens held by this vault
    function totalAssets() external view returns (uint256);

    /// @notice Returns the underlying CTF (ERC1155) contract
    function ctf() external view returns (IERC1155);

    /// @notice Returns the position ID this vault wraps
    function positionId() external view returns (uint256);
}
