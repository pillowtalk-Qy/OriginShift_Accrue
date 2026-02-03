// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";
import {MathLib} from "../libraries/MathLib.sol";

/// @title LendingPool
/// @notice Core lending pool for USDC deposits and borrows
/// @dev Implements interest accrual using index-based accounting
contract LendingPool is ILendingPool, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying asset (USDC)
    IERC20 public immutable usdc;

    /// @notice The interest rate model
    IInterestRateModel public interestRateModel;

    /// @notice The collateral manager
    ICollateralManager public collateralManager;

    /// @notice Lender information
    struct LenderInfo {
        uint256 shares; // Share balance
    }

    /// @notice Borrower information
    struct BorrowerInfo {
        uint256 principal; // Original borrow amount
        uint256 borrowIndex; // Index at time of borrow
    }

    mapping(address => LenderInfo) public lenders;
    mapping(address => BorrowerInfo) public borrowers;

    /// @notice Total shares issued to lenders
    uint256 public totalShares;

    /// @notice Total deposits (principal only, before interest)
    uint256 internal _totalDeposits;

    /// @notice Total borrows (principal only, before interest)
    uint256 internal _totalBorrows;

    /// @notice Liquidity index for deposits (starts at RAY)
    uint256 public liquidityIndex;

    /// @notice Borrow index (starts at RAY)
    uint256 public borrowIndex;

    /// @notice Last update timestamp
    uint256 public lastUpdateTimestamp;

    /// @notice Accumulated reserves
    uint256 public reserves;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LendingPool__InvalidAmount();
    error LendingPool__InsufficientLiquidity();
    error LendingPool__InsufficientCollateral();
    error LendingPool__InsufficientShares();
    error LendingPool__NoDebt();
    error LendingPool__NotCollateralManager();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _usdc, address _interestRateModel, address _owner) Ownable(_owner) {
        usdc = IERC20(_usdc);
        interestRateModel = IInterestRateModel(_interestRateModel);
        liquidityIndex = RAY;
        borrowIndex = RAY;
        lastUpdateTimestamp = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateState() {
        _updateIndexes();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           LENDER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILendingPool
    function deposit(uint256 amount) external nonReentrant whenNotPaused updateState returns (uint256 shares) {
        if (amount == 0) revert LendingPool__InvalidAmount();

        // Calculate shares to mint
        shares = convertToShares(amount);

        // Update state
        lenders[msg.sender].shares += shares;
        totalShares += shares;
        _totalDeposits += amount;

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, shares);
    }

    /// @inheritdoc ILendingPool
    function withdraw(uint256 shares) external nonReentrant whenNotPaused updateState returns (uint256 amount) {
        if (shares == 0) revert LendingPool__InvalidAmount();
        if (lenders[msg.sender].shares < shares) revert LendingPool__InsufficientShares();

        // Calculate assets to return
        amount = convertToAssets(shares);

        // Check liquidity
        if (amount > availableLiquidity()) revert LendingPool__InsufficientLiquidity();

        // Update state
        lenders[msg.sender].shares -= shares;
        totalShares -= shares;

        // Adjust total deposits proportionally
        uint256 depositReduction = MathLib.min(amount, _totalDeposits);
        _totalDeposits -= depositReduction;

        // Transfer USDC to user
        usdc.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, shares);
    }

    /// @inheritdoc ILendingPool
    function balanceOf(address lender) external view returns (uint256) {
        return convertToAssets(lenders[lender].shares);
    }

    /// @inheritdoc ILendingPool
    function sharesOf(address lender) external view returns (uint256) {
        return lenders[lender].shares;
    }

    /*//////////////////////////////////////////////////////////////
                          BORROWER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILendingPool
    function borrow(uint256 amount) external nonReentrant whenNotPaused updateState {
        if (amount == 0) revert LendingPool__InvalidAmount();
        if (amount > availableLiquidity()) revert LendingPool__InsufficientLiquidity();

        // Check collateral (this will revert if insufficient)
        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(msg.sender);
        uint256 currentDebt = debtOf(msg.sender);

        if (currentDebt + amount > maxBorrow) revert LendingPool__InsufficientCollateral();

        // Update borrower info
        BorrowerInfo storage borrower = borrowers[msg.sender];

        // If existing debt, we need to compound it first
        if (borrower.principal > 0) {
            // Convert existing debt to current value and add new borrow
            uint256 existingDebt = _calculateDebt(borrower.principal, borrower.borrowIndex);
            borrower.principal = existingDebt + amount;
        } else {
            borrower.principal = amount;
        }
        borrower.borrowIndex = borrowIndex;

        _totalBorrows += amount;

        // Transfer USDC to borrower
        usdc.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    /// @inheritdoc ILendingPool
    function repay(uint256 amount) external nonReentrant whenNotPaused updateState returns (uint256 repaid) {
        return _repay(msg.sender, amount);
    }

    /// @inheritdoc ILendingPool
    function repayFor(address borrower, uint256 amount) external nonReentrant whenNotPaused updateState returns (uint256 repaid) {
        return _repay(borrower, amount);
    }

    function _repay(address borrowerAddress, uint256 amount) internal returns (uint256 repaid) {
        BorrowerInfo storage borrower = borrowers[borrowerAddress];
        if (borrower.principal == 0) revert LendingPool__NoDebt();

        uint256 currentDebt = _calculateDebt(borrower.principal, borrower.borrowIndex);

        // Handle max repay
        if (amount == type(uint256).max) {
            repaid = currentDebt;
        } else {
            repaid = MathLib.min(amount, currentDebt);
        }

        // Transfer USDC from payer
        usdc.safeTransferFrom(msg.sender, address(this), repaid);

        // Update borrower info
        if (repaid >= currentDebt) {
            // Full repay
            borrower.principal = 0;
            borrower.borrowIndex = 0;
        } else {
            // Partial repay - update principal at current index
            borrower.principal = currentDebt - repaid;
            borrower.borrowIndex = borrowIndex;
        }

        // Update total borrows
        _totalBorrows = MathLib.zeroFloorSub(_totalBorrows, repaid);

        emit Repay(borrowerAddress, repaid);
    }

    /// @inheritdoc ILendingPool
    function debtOf(address borrower) public view returns (uint256) {
        BorrowerInfo memory info = borrowers[borrower];
        if (info.principal == 0) return 0;

        // Calculate current index with pending interest
        uint256 currentBorrowIndex = _calculateCurrentBorrowIndex();
        return _calculateDebt(info.principal, info.borrowIndex, currentBorrowIndex);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILendingPool
    function getUtilizationRate() public view returns (uint256) {
        uint256 totalLiquidity = _totalDeposits;
        if (totalLiquidity == 0) return 0;

        return (_totalBorrows * WAD) / totalLiquidity;
    }

    /// @inheritdoc ILendingPool
    function getCurrentRates() external view returns (uint256 depositRate, uint256 borrowRate) {
        uint256 utilization = getUtilizationRate();
        borrowRate = interestRateModel.getBorrowRate(utilization);
        depositRate = interestRateModel.getDepositRate(utilization);
    }

    /// @inheritdoc ILendingPool
    function totalDeposits() external view returns (uint256) {
        return _totalDeposits;
    }

    /// @inheritdoc ILendingPool
    function totalBorrows() external view returns (uint256) {
        return _totalBorrows;
    }

    /// @inheritdoc ILendingPool
    function availableLiquidity() public view returns (uint256) {
        return usdc.balanceOf(address(this)) - reserves;
    }

    /// @inheritdoc ILendingPool
    function asset() external view returns (address) {
        return address(usdc);
    }

    /// @inheritdoc ILendingPool
    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalShares == 0) return shares;

        uint256 currentLiquidityIndex = _calculateCurrentLiquidityIndex();
        return shares.rayMul(currentLiquidityIndex).rayToWad();
    }

    /// @inheritdoc ILendingPool
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 currentLiquidityIndex = _calculateCurrentLiquidityIndex();
        if (currentLiquidityIndex == 0) return assets;

        return assets.wadToRay().rayDiv(currentLiquidityIndex);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _updateIndexes() internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed == 0) return;

        uint256 utilization = getUtilizationRate();
        uint256 borrowRate = interestRateModel.getBorrowRate(utilization);
        uint256 depositRate = interestRateModel.getDepositRate(utilization);

        // Update borrow index (convert WAD rate to RAY)
        uint256 borrowInterestRay = borrowRate * timeElapsed * 1e9;
        borrowIndex = borrowIndex.rayMul(RAY + borrowInterestRay);

        // Update liquidity index (convert WAD rate to RAY)
        uint256 depositInterestRay = depositRate * timeElapsed * 1e9;
        liquidityIndex = liquidityIndex.rayMul(RAY + depositInterestRay);

        lastUpdateTimestamp = block.timestamp;

        emit InterestAccrued(_totalDeposits, _totalBorrows, block.timestamp);
    }

    function _calculateCurrentLiquidityIndex() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed == 0) return liquidityIndex;

        uint256 utilization = getUtilizationRate();
        uint256 depositRate = interestRateModel.getDepositRate(utilization);
        // depositRate is per-second in WAD (18 decimals), convert to RAY (27 decimals)
        uint256 depositInterestRay = depositRate * timeElapsed * 1e9;

        return liquidityIndex.rayMul(RAY + depositInterestRay);
    }

    function _calculateCurrentBorrowIndex() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed == 0) return borrowIndex;

        uint256 utilization = getUtilizationRate();
        uint256 borrowRate = interestRateModel.getBorrowRate(utilization);
        // borrowRate is per-second in WAD (18 decimals), convert to RAY (27 decimals)
        uint256 borrowInterestRay = borrowRate * timeElapsed * 1e9;

        return borrowIndex.rayMul(RAY + borrowInterestRay);
    }

    function _calculateDebt(uint256 principal, uint256 userBorrowIndex) internal view returns (uint256) {
        return _calculateDebt(principal, userBorrowIndex, borrowIndex);
    }

    function _calculateDebt(uint256 principal, uint256 userBorrowIndex, uint256 currentIndex)
        internal
        pure
        returns (uint256)
    {
        if (userBorrowIndex == 0) return principal;
        // debt = principal * currentIndex / userBorrowIndex
        return (principal * currentIndex) / userBorrowIndex;
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setCollateralManager(address _collateralManager) external onlyOwner {
        collateralManager = ICollateralManager(_collateralManager);
    }

    function setInterestRateModel(address _interestRateModel) external onlyOwner {
        interestRateModel = IInterestRateModel(_interestRateModel);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Withdraw accumulated reserves
    function withdrawReserves(uint256 amount, address to) external onlyOwner {
        require(amount <= reserves, "Insufficient reserves");
        reserves -= amount;
        usdc.safeTransfer(to, amount);
    }
}
