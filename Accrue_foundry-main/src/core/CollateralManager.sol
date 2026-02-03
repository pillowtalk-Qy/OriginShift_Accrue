// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title CollateralManager
/// @notice Manages user collateral positions and health factor calculations
contract CollateralManager is ICollateralManager, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PercentageMath for uint256;
    using WadRayMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Basis points denominator (10000 = 100%)
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Health factor precision (18 decimals)
    uint256 public constant HEALTH_FACTOR_PRECISION = 1e18;

    /// @notice USDC decimals
    uint256 public constant USDC_DECIMALS = 6;

    /// @notice Price decimals
    uint256 public constant PRICE_DECIMALS = 8;

    /// @notice Position token decimals
    uint256 public constant POSITION_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The lending pool
    ILendingPool public lendingPool;

    /// @notice The price oracle
    IPriceOracle public priceOracle;

    /// @notice The liquidation engine (authorized to seize collateral)
    address public liquidationEngine;

    /// @notice Collateral configurations
    mapping(address => CollateralConfig) internal _collateralConfigs;

    /// @notice User collateral positions: user => vault => amount
    mapping(address => mapping(address => uint256)) internal _userCollaterals;

    /// @notice User's collateral vault list
    mapping(address => EnumerableSet.AddressSet) internal _userCollateralVaults;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error CollateralManager__InvalidAmount();
    error CollateralManager__CollateralNotActive();
    error CollateralManager__InsufficientCollateral();
    error CollateralManager__WouldBeLiquidatable();
    error CollateralManager__NotLiquidationEngine();
    error CollateralManager__InvalidConfig();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _lendingPool, address _priceOracle, address _owner) Ownable(_owner) {
        lendingPool = ILendingPool(_lendingPool);
        priceOracle = IPriceOracle(_priceOracle);
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyLiquidationEngine() {
        if (msg.sender != liquidationEngine) revert CollateralManager__NotLiquidationEngine();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         COLLATERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollateralManager
    function depositCollateral(address vault, uint256 amount) external nonReentrant {
        if (amount == 0) revert CollateralManager__InvalidAmount();

        CollateralConfig memory config = _collateralConfigs[vault];
        if (!config.isActive) revert CollateralManager__CollateralNotActive();

        // Transfer collateral from user
        IERC20(vault).safeTransferFrom(msg.sender, address(this), amount);

        // Update user's collateral
        _userCollaterals[msg.sender][vault] += amount;
        _userCollateralVaults[msg.sender].add(vault);

        emit CollateralDeposited(msg.sender, vault, amount);
    }

    /// @inheritdoc ICollateralManager
    function withdrawCollateral(address vault, uint256 amount) external nonReentrant {
        if (amount == 0) revert CollateralManager__InvalidAmount();

        uint256 currentAmount = _userCollaterals[msg.sender][vault];
        if (currentAmount < amount) revert CollateralManager__InsufficientCollateral();

        // Temporarily update to check health factor
        _userCollaterals[msg.sender][vault] = currentAmount - amount;

        // Check if withdrawal would make position liquidatable
        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < HEALTH_FACTOR_PRECISION && lendingPool.debtOf(msg.sender) > 0) {
            // Revert the change
            _userCollaterals[msg.sender][vault] = currentAmount;
            revert CollateralManager__WouldBeLiquidatable();
        }

        // Remove vault from list if empty
        if (_userCollaterals[msg.sender][vault] == 0) {
            _userCollateralVaults[msg.sender].remove(vault);
        }

        // Transfer collateral to user
        IERC20(vault).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, vault, amount);
    }

    /// @inheritdoc ICollateralManager
    function getCollateralAmount(address user, address vault) external view returns (uint256) {
        return _userCollaterals[user][vault];
    }

    /// @inheritdoc ICollateralManager
    function getUserCollaterals(address user) external view returns (address[] memory vaults, uint256[] memory amounts) {
        uint256 length = _userCollateralVaults[user].length();
        vaults = new address[](length);
        amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            vaults[i] = _userCollateralVaults[user].at(i);
            amounts[i] = _userCollaterals[user][vaults[i]];
        }
    }

    /*//////////////////////////////////////////////////////////////
                           VALUE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollateralManager
    function getTotalCollateralValue(address user) public view returns (uint256 totalValue) {
        uint256 length = _userCollateralVaults[user].length();

        for (uint256 i = 0; i < length; i++) {
            address vault = _userCollateralVaults[user].at(i);
            uint256 amount = _userCollaterals[user][vault];

            if (amount > 0) {
                // Get value in USD (8 decimals)
                totalValue += priceOracle.getAssetValue(vault, amount);
            }
        }
    }

    /// @inheritdoc ICollateralManager
    function getAdjustedCollateralValue(address user) public view returns (uint256 adjustedValue) {
        uint256 length = _userCollateralVaults[user].length();

        for (uint256 i = 0; i < length; i++) {
            address vault = _userCollateralVaults[user].at(i);
            uint256 amount = _userCollaterals[user][vault];

            if (amount > 0) {
                CollateralConfig memory config = _collateralConfigs[vault];
                uint256 value = priceOracle.getAssetValue(vault, amount);

                // Adjust by liquidation threshold for health factor calculation
                adjustedValue += value.percentMul(config.liquidationThreshold);
            }
        }
    }

    /// @inheritdoc ICollateralManager
    function getMaxBorrowAmount(address user) external view returns (uint256) {
        uint256 length = _userCollateralVaults[user].length();
        uint256 maxBorrowValue = 0; // in 8 decimals (USD)

        for (uint256 i = 0; i < length; i++) {
            address vault = _userCollateralVaults[user].at(i);
            uint256 amount = _userCollaterals[user][vault];

            if (amount > 0) {
                CollateralConfig memory config = _collateralConfigs[vault];
                uint256 value = priceOracle.getAssetValue(vault, amount);

                // Adjust by LTV
                maxBorrowValue += value.percentMul(config.ltv);
            }
        }

        // Convert from 8 decimals to 6 decimals (USDC)
        return maxBorrowValue / 100;
    }

    /*//////////////////////////////////////////////////////////////
                            HEALTH FACTOR
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollateralManager
    function getHealthFactor(address user) public view returns (uint256) {
        uint256 debt = lendingPool.debtOf(user);
        if (debt == 0) return type(uint256).max;

        uint256 adjustedCollateral = getAdjustedCollateralValue(user); // 8 decimals

        // Convert debt from 6 decimals to 8 decimals for comparison
        uint256 debtIn8Decimals = debt * 100;

        // healthFactor = adjustedCollateral / debt (in 18 decimals)
        return (adjustedCollateral * HEALTH_FACTOR_PRECISION) / debtIn8Decimals;
    }

    /// @inheritdoc ICollateralManager
    function isLiquidatable(address user) external view returns (bool) {
        return getHealthFactor(user) < HEALTH_FACTOR_PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION SUPPORT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollateralManager
    function seizeCollateral(address user, address vault, uint256 amount) external onlyLiquidationEngine {
        uint256 currentAmount = _userCollaterals[user][vault];
        if (currentAmount < amount) revert CollateralManager__InsufficientCollateral();

        _userCollaterals[user][vault] = currentAmount - amount;

        if (_userCollaterals[user][vault] == 0) {
            _userCollateralVaults[user].remove(vault);
        }

        // Transfer to liquidation engine
        IERC20(vault).safeTransfer(liquidationEngine, amount);

        emit CollateralSeized(user, vault, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollateralManager
    function setCollateralConfig(address vault, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus)
        external
        onlyOwner
    {
        if (ltv > liquidationThreshold) revert CollateralManager__InvalidConfig();
        if (liquidationThreshold > BASIS_POINTS) revert CollateralManager__InvalidConfig();
        if (liquidationBonus > 2000) revert CollateralManager__InvalidConfig(); // Max 20% bonus

        _collateralConfigs[vault] = CollateralConfig({
            isActive: true,
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            decimals: 18
        });

        emit CollateralConfigUpdated(vault, ltv, liquidationThreshold, liquidationBonus);
    }

    /// @notice Deactivate a collateral type
    function deactivateCollateral(address vault) external onlyOwner {
        _collateralConfigs[vault].isActive = false;
    }

    /// @notice Set the liquidation engine address
    function setLiquidationEngine(address _liquidationEngine) external onlyOwner {
        liquidationEngine = _liquidationEngine;
    }

    /// @notice Set the price oracle
    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }

    /// @notice Set the lending pool
    function setLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
    }

    /// @inheritdoc ICollateralManager
    function getCollateralConfig(address vault) external view returns (CollateralConfig memory) {
        return _collateralConfigs[vault];
    }
}
