// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/// @title PriceOracle
/// @notice Simple admin-controlled price oracle for Position Vaults
/// @dev In production, integrate with Chainlink, UMA, or other decentralized oracles
contract PriceOracle is IPriceOracle, Ownable {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Price precision (8 decimals, same as Chainlink)
    uint8 public constant DECIMALS = 8;

    /// @notice Position token decimals (18)
    uint256 public constant POSITION_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Price data for each vault
    struct PriceData {
        uint256 price; // Price in USD (8 decimals)
        uint256 lastUpdated; // Timestamp of last update
        bool isValid; // Whether price is valid
    }

    mapping(address => PriceData) internal _prices;

    /// @notice Maximum staleness period (default: 1 day)
    uint256 public maxStaleness = 1 days;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PriceOracle__InvalidPrice();
    error PriceOracle__PriceNotSet();
    error PriceOracle__StalePrice();
    error PriceOracle__LengthMismatch();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Ownable(_owner) {}

    /*//////////////////////////////////////////////////////////////
                            PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPriceOracle
    function getPrice(address vault) public view returns (uint256) {
        PriceData memory data = _prices[vault];

        if (!data.isValid) revert PriceOracle__PriceNotSet();
        if (block.timestamp - data.lastUpdated > maxStaleness) revert PriceOracle__StalePrice();

        return data.price;
    }

    /// @inheritdoc IPriceOracle
    function getAssetValue(address vault, uint256 amount) external view returns (uint256) {
        uint256 price = getPrice(vault);

        // amount is in 18 decimals (position tokens)
        // price is in 8 decimals (USD)
        // result should be in 8 decimals (USD)
        // value = amount * price / 10^18
        return (amount * price) / (10 ** POSITION_DECIMALS);
    }

    /// @inheritdoc IPriceOracle
    function isPriceValid(address vault) external view returns (bool) {
        PriceData memory data = _prices[vault];
        return data.isValid && (block.timestamp - data.lastUpdated <= maxStaleness);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPriceOracle
    function setPrice(address vault, uint256 price) external onlyOwner {
        if (price == 0) revert PriceOracle__InvalidPrice();

        uint256 oldPrice = _prices[vault].price;
        _prices[vault] = PriceData({price: price, lastUpdated: block.timestamp, isValid: true});

        emit PriceUpdated(vault, oldPrice, price, block.timestamp);
    }

    /// @inheritdoc IPriceOracle
    function setPrices(address[] calldata vaults, uint256[] calldata prices) external onlyOwner {
        if (vaults.length != prices.length) revert PriceOracle__LengthMismatch();

        for (uint256 i = 0; i < vaults.length; i++) {
            if (prices[i] == 0) revert PriceOracle__InvalidPrice();

            uint256 oldPrice = _prices[vaults[i]].price;
            _prices[vaults[i]] = PriceData({price: prices[i], lastUpdated: block.timestamp, isValid: true});

            emit PriceUpdated(vaults[i], oldPrice, prices[i], block.timestamp);
        }
    }

    /// @inheritdoc IPriceOracle
    function invalidatePrice(address vault) external onlyOwner {
        _prices[vault].isValid = false;
        emit PriceInvalidated(vault);
    }

    /// @inheritdoc IPriceOracle
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        maxStaleness = newMaxStaleness;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPriceOracle
    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    /// @inheritdoc IPriceOracle
    function getPriceData(address vault) external view returns (uint256 price, uint256 lastUpdated, bool isValid) {
        PriceData memory data = _prices[vault];
        return (data.price, data.lastUpdated, data.isValid);
    }
}
