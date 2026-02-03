// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPositionVault} from "../interfaces/IPositionVault.sol";
import {IPositionVaultFactory} from "../interfaces/IPositionVaultFactory.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";

/// @title PolyLendRouter
/// @notice Simplified router for common PolyLend operations
/// @dev Aggregates multiple operations into single transactions
contract PolyLendRouter is ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The position vault factory
    IPositionVaultFactory public immutable factory;

    /// @notice The lending pool
    ILendingPool public immutable lendingPool;

    /// @notice The collateral manager
    ICollateralManager public immutable collateralManager;

    /// @notice The CTF (Conditional Token Framework)
    IERC1155 public immutable ctf;

    /// @notice The USDC token
    IERC20 public immutable usdc;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositCollateralAndBorrow(
        address indexed user, uint256 indexed positionId, uint256 collateralAmount, uint256 borrowAmount
    );
    event RepayAndWithdrawCollateral(
        address indexed user, uint256 indexed positionId, uint256 repayAmount, uint256 withdrawAmount
    );
    event DepositCollateral(address indexed user, uint256 indexed positionId, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 indexed positionId, uint256 amount);
    event DepositLiquidity(address indexed user, uint256 amount);
    event WithdrawLiquidity(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PolyLendRouter__VaultNotFound();
    error PolyLendRouter__InvalidAmount();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _factory, address _lendingPool, address _collateralManager) {
        factory = IPositionVaultFactory(_factory);
        lendingPool = ILendingPool(_lendingPool);
        collateralManager = ICollateralManager(_collateralManager);
        ctf = IERC1155(factory.ctf());
        usdc = IERC20(lendingPool.asset());
    }

    /*//////////////////////////////////////////////////////////////
                          BORROWER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit collateral and borrow USDC in one transaction
    /// @param positionId The Polymarket position ID
    /// @param collateralAmount Amount of position tokens to deposit
    /// @param borrowAmount Amount of USDC to borrow
    /// @dev User must approve CTF tokens to this router first
    function depositCollateralAndBorrow(uint256 positionId, uint256 collateralAmount, uint256 borrowAmount)
        external
        nonReentrant
    {
        if (collateralAmount == 0) revert PolyLendRouter__InvalidAmount();

        address vault = factory.getVault(positionId);
        if (vault == address(0)) revert PolyLendRouter__VaultNotFound();

        // 1. Transfer CTF from user to router
        ctf.safeTransferFrom(msg.sender, address(this), positionId, collateralAmount, "");

        // 2. Approve and deposit into PositionVault
        ctf.setApprovalForAll(vault, true);
        IPositionVault(vault).deposit(collateralAmount, address(this));

        // 3. Approve and deposit collateral into CollateralManager
        IERC20(vault).forceApprove(address(collateralManager), collateralAmount);
        collateralManager.depositCollateral(vault, collateralAmount);

        // Note: CollateralManager tracks collateral for msg.sender, but we deposited from router
        // We need to use a different pattern - let user call directly or use permit

        // 4. Borrow USDC if requested
        if (borrowAmount > 0) {
            lendingPool.borrow(borrowAmount);
            usdc.safeTransfer(msg.sender, borrowAmount);
        }

        emit DepositCollateralAndBorrow(msg.sender, positionId, collateralAmount, borrowAmount);
    }

    /// @notice Repay USDC and withdraw collateral in one transaction
    /// @param positionId The Polymarket position ID
    /// @param repayAmount Amount of USDC to repay (use type(uint256).max for full repay)
    /// @param withdrawAmount Amount of collateral to withdraw
    /// @dev User must approve USDC to this router first
    function repayAndWithdrawCollateral(uint256 positionId, uint256 repayAmount, uint256 withdrawAmount)
        external
        nonReentrant
    {
        address vault = factory.getVault(positionId);
        if (vault == address(0)) revert PolyLendRouter__VaultNotFound();

        // 1. Repay USDC if requested
        if (repayAmount > 0) {
            uint256 actualRepay = repayAmount;
            if (repayAmount == type(uint256).max) {
                actualRepay = lendingPool.debtOf(msg.sender);
            }

            usdc.safeTransferFrom(msg.sender, address(this), actualRepay);
            usdc.forceApprove(address(lendingPool), actualRepay);
            lendingPool.repay(actualRepay);
        }

        // 2. Withdraw collateral if requested
        if (withdrawAmount > 0) {
            collateralManager.withdrawCollateral(vault, withdrawAmount);

            // 3. Withdraw from PositionVault and send CTF to user
            IPositionVault(vault).withdraw(withdrawAmount, msg.sender);
        }

        emit RepayAndWithdrawCollateral(msg.sender, positionId, repayAmount, withdrawAmount);
    }

    /// @notice Deposit collateral only (no borrowing)
    /// @param positionId The Polymarket position ID
    /// @param amount Amount of position tokens to deposit
    function depositCollateralOnly(uint256 positionId, uint256 amount) external nonReentrant {
        if (amount == 0) revert PolyLendRouter__InvalidAmount();

        address vault = factory.getVault(positionId);
        if (vault == address(0)) revert PolyLendRouter__VaultNotFound();

        // Transfer CTF from user
        ctf.safeTransferFrom(msg.sender, address(this), positionId, amount, "");

        // Deposit into PositionVault
        ctf.setApprovalForAll(vault, true);
        IPositionVault(vault).deposit(amount, address(this));

        // Deposit collateral
        IERC20(vault).forceApprove(address(collateralManager), amount);
        collateralManager.depositCollateral(vault, amount);

        emit DepositCollateral(msg.sender, positionId, amount);
    }

    /// @notice Withdraw collateral only
    /// @param positionId The Polymarket position ID
    /// @param amount Amount to withdraw
    function withdrawCollateralOnly(uint256 positionId, uint256 amount) external nonReentrant {
        if (amount == 0) revert PolyLendRouter__InvalidAmount();

        address vault = factory.getVault(positionId);
        if (vault == address(0)) revert PolyLendRouter__VaultNotFound();

        // Withdraw from CollateralManager
        collateralManager.withdrawCollateral(vault, amount);

        // Withdraw from PositionVault and send CTF to user
        IPositionVault(vault).withdraw(amount, msg.sender);

        emit WithdrawCollateral(msg.sender, positionId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          LENDER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit USDC to provide liquidity
    /// @param amount Amount of USDC to deposit
    function depositLiquidity(uint256 amount) external nonReentrant {
        if (amount == 0) revert PolyLendRouter__InvalidAmount();

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.forceApprove(address(lendingPool), amount);
        lendingPool.deposit(amount);

        emit DepositLiquidity(msg.sender, amount);
    }

    /// @notice Withdraw USDC liquidity
    /// @param shares Amount of shares to withdraw
    function withdrawLiquidity(uint256 shares) external nonReentrant {
        if (shares == 0) revert PolyLendRouter__InvalidAmount();

        uint256 amount = lendingPool.withdraw(shares);
        usdc.safeTransfer(msg.sender, amount);

        emit WithdrawLiquidity(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get vault address for a position ID
    function getVault(uint256 positionId) external view returns (address) {
        return factory.getVault(positionId);
    }

    /// @notice Get user's collateral amount for a position
    function getUserCollateral(uint256 positionId, address user) external view returns (uint256) {
        address vault = factory.getVault(positionId);
        if (vault == address(0)) return 0;
        return collateralManager.getCollateralAmount(user, vault);
    }

    /// @notice Get user's debt
    function getUserDebt(address user) external view returns (uint256) {
        return lendingPool.debtOf(user);
    }

    /// @notice Get user's health factor
    function getUserHealthFactor(address user) external view returns (uint256) {
        return collateralManager.getHealthFactor(user);
    }

    /// @notice Get user's max borrow amount
    function getUserMaxBorrow(address user) external view returns (uint256) {
        return collateralManager.getMaxBorrowAmount(user);
    }
}
