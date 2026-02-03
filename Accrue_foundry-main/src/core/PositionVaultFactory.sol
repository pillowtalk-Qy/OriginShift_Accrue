// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PositionVault} from "./PositionVault.sol";
import {IPositionVaultFactory} from "../interfaces/IPositionVaultFactory.sol";

/// @title PositionVaultFactory
/// @notice Factory contract for creating PositionVault instances
/// @dev Each position ID gets its own vault
contract PositionVaultFactory is IPositionVaultFactory, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Polymarket CTF (Conditional Token Framework) address
    address public immutable ctf;

    /// @notice Mapping from position ID to vault address
    mapping(uint256 => address) public vaults;

    /// @notice Array of all created vaults
    address[] public allVaults;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PositionVaultFactory__VaultAlreadyExists();
    error PositionVaultFactory__InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _ctf, address _owner) Ownable(_owner) {
        if (_ctf == address(0)) revert PositionVaultFactory__InvalidAddress();
        ctf = _ctf;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPositionVaultFactory
    function createVault(uint256 positionId, string memory name, string memory symbol)
        external
        returns (address vault)
    {
        if (vaults[positionId] != address(0)) revert PositionVaultFactory__VaultAlreadyExists();

        vault = address(new PositionVault(ctf, positionId, name, symbol));

        vaults[positionId] = vault;
        allVaults.push(vault);

        emit VaultCreated(positionId, vault, name, symbol);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPositionVaultFactory
    function getVault(uint256 positionId) external view returns (address) {
        return vaults[positionId];
    }

    /// @inheritdoc IPositionVaultFactory
    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }

    /// @inheritdoc IPositionVaultFactory
    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}
