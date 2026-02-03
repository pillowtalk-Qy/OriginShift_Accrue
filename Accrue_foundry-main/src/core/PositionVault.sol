// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPositionVault} from "../interfaces/IPositionVault.sol";

/// @title PositionVault
/// @notice Wraps Polymarket ERC1155 Position tokens into ERC20 tokens
/// @dev Each vault handles a single position ID, minting 1:1 ERC20 shares
contract PositionVault is IPositionVault, ERC20, ERC1155Holder, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Polymarket CTF (Conditional Token Framework) contract
    IERC1155 public immutable ctf;

    /// @notice The position ID this vault wraps
    uint256 public immutable positionId;

    /// @notice The factory that created this vault
    address public immutable factory;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PositionVault__InvalidAmount();
    error PositionVault__InvalidPositionId();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _ctf, uint256 _positionId, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        ctf = IERC1155(_ctf);
        positionId = _positionId;
        factory = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPositionVault
    function deposit(uint256 amount, address receiver) external nonReentrant returns (uint256 shares) {
        if (amount == 0) revert PositionVault__InvalidAmount();

        shares = amount; // 1:1 ratio

        // Transfer CTF tokens from sender to vault
        ctf.safeTransferFrom(msg.sender, address(this), positionId, amount, "");

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, amount);
    }

    /// @inheritdoc IPositionVault
    function withdraw(uint256 amount, address receiver) external nonReentrant returns (uint256 assets) {
        if (amount == 0) revert PositionVault__InvalidAmount();

        assets = amount; // 1:1 ratio

        // Burn shares from sender
        _burn(msg.sender, amount);

        // Transfer CTF tokens to receiver
        ctf.safeTransferFrom(address(this), receiver, positionId, assets, "");

        emit Withdraw(msg.sender, receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPositionVault
    function totalAssets() external view returns (uint256) {
        return ctf.balanceOf(address(this), positionId);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC1155 RECEIVER
    //////////////////////////////////////////////////////////////*/

    /// @notice Only accept the correct position ID
    function onERC1155Received(address, address, uint256 id, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        if (id != positionId) revert PositionVault__InvalidPositionId();
        return this.onERC1155Received.selector;
    }

    /// @notice Only accept the correct position ID in batch
    function onERC1155BatchReceived(address, address, uint256[] memory ids, uint256[] memory, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] != positionId) revert PositionVault__InvalidPositionId();
        }
        return this.onERC1155BatchReceived.selector;
    }
}
