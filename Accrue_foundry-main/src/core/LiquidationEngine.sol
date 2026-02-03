// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ILiquidationEngine} from "../interfaces/ILiquidationEngine.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {MathLib} from "../libraries/MathLib.sol";

/// @title LiquidationEngine
/// @notice Handles liquidation of undercollateralized positions
contract LiquidationEngine is ILiquidationEngine, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PercentageMath for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Basis points denominator
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Health factor threshold (1e18 = 1.0)
    uint256 public constant HEALTH_FACTOR_THRESHOLD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The lending pool
    ILendingPool public lendingPool;

    /// @notice The collateral manager
    ICollateralManager public collateralManager;

    /// @notice The price oracle
    IPriceOracle public priceOracle;

    /// @notice Close factor - max percentage of debt that can be repaid in one liquidation
    /// @dev 5000 = 50%
    uint256 public closeFactor = 5000;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LiquidationEngine__NotLiquidatable();
    error LiquidationEngine__InvalidAmount();
    error LiquidationEngine__ExceedsCloseAmount();
    error LiquidationEngine__InsufficientCollateral();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _lendingPool, address _collateralManager, address _priceOracle, address _owner)
        Ownable(_owner)
    {
        lendingPool = ILendingPool(_lendingPool);
        collateralManager = ICollateralManager(_collateralManager);
        priceOracle = IPriceOracle(_priceOracle);
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILiquidationEngine
    function liquidate(address borrower, address collateralVault, uint256 debtToRepay)
        external
        nonReentrant
        returns (uint256 collateralSeized)
    {
        // Check if position is liquidatable
        if (!canLiquidate(borrower)) revert LiquidationEngine__NotLiquidatable();
        if (debtToRepay == 0) revert LiquidationEngine__InvalidAmount();

        // Get borrower's total debt
        uint256 totalDebt = lendingPool.debtOf(borrower);

        // Calculate max repayable amount based on close factor
        uint256 maxRepay = totalDebt.percentMul(closeFactor);
        if (debtToRepay > maxRepay) revert LiquidationEngine__ExceedsCloseAmount();

        // Calculate collateral to seize (including bonus)
        collateralSeized = calculateCollateralToSeize(collateralVault, debtToRepay);

        // Check if borrower has enough collateral
        uint256 borrowerCollateral = collateralManager.getCollateralAmount(borrower, collateralVault);
        if (borrowerCollateral < collateralSeized) revert LiquidationEngine__InsufficientCollateral();

        // Transfer USDC from liquidator to repay debt
        address usdc = lendingPool.asset();
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), debtToRepay);

        // Approve and repay debt on behalf of borrower
        IERC20(usdc).forceApprove(address(lendingPool), debtToRepay);
        lendingPool.repayFor(borrower, debtToRepay);

        // Seize collateral from borrower
        collateralManager.seizeCollateral(borrower, collateralVault, collateralSeized);

        // Transfer collateral to liquidator
        IERC20(collateralVault).safeTransfer(msg.sender, collateralSeized);

        emit Liquidation(msg.sender, borrower, collateralVault, debtToRepay, collateralSeized);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILiquidationEngine
    function getLiquidationInfo(address borrower, address collateralVault)
        external
        view
        returns (uint256 maxDebtToRepay, uint256 collateralToReceive)
    {
        if (!canLiquidate(borrower)) {
            return (0, 0);
        }

        uint256 totalDebt = lendingPool.debtOf(borrower);
        maxDebtToRepay = totalDebt.percentMul(closeFactor);

        // Cap by available collateral
        uint256 borrowerCollateral = collateralManager.getCollateralAmount(borrower, collateralVault);
        uint256 maxSeizable = calculateCollateralToSeize(collateralVault, maxDebtToRepay);

        if (maxSeizable > borrowerCollateral) {
            // Reverse calculate: how much debt can we repay with available collateral?
            maxDebtToRepay = _calculateDebtFromCollateral(collateralVault, borrowerCollateral);
            collateralToReceive = borrowerCollateral;
        } else {
            collateralToReceive = maxSeizable;
        }
    }

    /// @inheritdoc ILiquidationEngine
    function calculateCollateralToSeize(address collateralVault, uint256 debtToRepay) public view returns (uint256) {
        // Get collateral price (8 decimals)
        uint256 collateralPrice = priceOracle.getPrice(collateralVault);

        // Get liquidation bonus
        ICollateralManager.CollateralConfig memory config = collateralManager.getCollateralConfig(collateralVault);
        uint256 bonus = config.liquidationBonus;

        // debtToRepay is in USDC (6 decimals)
        // collateralPrice is in USD per token (8 decimals)
        // We want collateral amount in 18 decimals

        // collateralValue = debtToRepay * (1 + bonus)
        // collateralAmount = collateralValue / price

        // Convert debt to 8 decimals for calculation
        uint256 debtValue = debtToRepay * 100; // 6 decimals -> 8 decimals

        // Add bonus
        uint256 collateralValueWithBonus = debtValue + debtValue.percentMul(bonus);

        // Calculate collateral amount (18 decimals)
        // amount = value * 10^18 / price
        return (collateralValueWithBonus * 1e18) / collateralPrice;
    }

    /// @inheritdoc ILiquidationEngine
    function canLiquidate(address borrower) public view returns (bool) {
        uint256 healthFactor = collateralManager.getHealthFactor(borrower);
        return healthFactor < HEALTH_FACTOR_THRESHOLD;
    }

    /// @inheritdoc ILiquidationEngine
    function getLiquidationBonus(address collateralVault) external view returns (uint256) {
        ICollateralManager.CollateralConfig memory config = collateralManager.getCollateralConfig(collateralVault);
        return config.liquidationBonus;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate debt amount from collateral amount
    function _calculateDebtFromCollateral(address collateralVault, uint256 collateralAmount)
        internal
        view
        returns (uint256)
    {
        uint256 collateralPrice = priceOracle.getPrice(collateralVault);
        ICollateralManager.CollateralConfig memory config = collateralManager.getCollateralConfig(collateralVault);
        uint256 bonus = config.liquidationBonus;

        // collateralValue = collateralAmount * price / 10^18 (in 8 decimals)
        uint256 collateralValue = (collateralAmount * collateralPrice) / 1e18;

        // Remove bonus: debtValue = collateralValue / (1 + bonus)
        uint256 debtValue = (collateralValue * BASIS_POINTS) / (BASIS_POINTS + bonus);

        // Convert from 8 decimals to 6 decimals (USDC)
        return debtValue / 100;
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the close factor
    /// @param _closeFactor New close factor in basis points
    function setCloseFactor(uint256 _closeFactor) external onlyOwner {
        require(_closeFactor <= BASIS_POINTS, "Invalid close factor");
        closeFactor = _closeFactor;
    }

    /// @notice Update contract references
    function setLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
    }

    function setCollateralManager(address _collateralManager) external onlyOwner {
        collateralManager = ICollateralManager(_collateralManager);
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }
}
