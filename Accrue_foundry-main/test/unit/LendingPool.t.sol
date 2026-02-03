// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {PositionVault} from "../../src/core/PositionVault.sol";

contract LendingPoolTest is BaseTest {
    PositionVault public vault;

    function setUp() public override {
        super.setUp();
        vault = PositionVault(_createAndConfigureVault(POSITION_ID_YES, "PolyLend YES", "pYES"));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deposit() public {
        uint256 amount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(lendingPool), amount);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 shares = lendingPool.deposit(amount);
        uint256 usdcAfter = usdc.balanceOf(alice);
        vm.stopPrank();

        assertEq(usdcBefore - usdcAfter, amount, "USDC not transferred");
        assertGt(shares, 0, "No shares minted");
        assertEq(lendingPool.sharesOf(alice), shares, "Shares not recorded");
    }

    function test_deposit_multiple() public {
        _provideLiquidity(alice, 10_000e6);
        _provideLiquidity(bob, 20_000e6);

        assertGt(lendingPool.sharesOf(alice), 0);
        assertGt(lendingPool.sharesOf(bob), 0);
    }

    function test_revert_deposit_zero() public {
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e6);

        vm.expectRevert(LendingPool.LendingPool__InvalidAmount.selector);
        lendingPool.deposit(0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdraw() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(lendingPool), depositAmount);
        uint256 shares = lendingPool.deposit(depositAmount);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 withdrawn = lendingPool.withdraw(shares);
        uint256 usdcAfter = usdc.balanceOf(alice);
        vm.stopPrank();

        assertEq(usdcAfter - usdcBefore, withdrawn);
        assertEq(lendingPool.sharesOf(alice), 0);
    }

    function test_revert_withdraw_insufficientShares() public {
        _provideLiquidity(alice, 10_000e6);

        uint256 shares = lendingPool.sharesOf(alice);

        vm.prank(alice);
        vm.expectRevert(LendingPool.LendingPool__InsufficientShares.selector);
        lendingPool.withdraw(shares + 1);
    }

    /*//////////////////////////////////////////////////////////////
                             BORROW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_borrow() public {
        // Setup: provide liquidity and deposit collateral
        _provideLiquidity(bob, 50_000e6);

        // Alice deposits collateral
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        // Calculate max borrow
        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);
        uint256 borrowAmount = maxBorrow / 2; // Borrow 50% of max

        // Borrow
        vm.prank(alice);
        lendingPool.borrow(borrowAmount);

        assertEq(usdc.balanceOf(alice), INITIAL_USDC_BALANCE + borrowAmount);
        assertGt(lendingPool.debtOf(alice), 0);
    }

    function test_revert_borrow_insufficientCollateral() public {
        _provideLiquidity(bob, 50_000e6);

        // Alice tries to borrow without collateral
        vm.prank(alice);
        vm.expectRevert(LendingPool.LendingPool__InsufficientCollateral.selector);
        lendingPool.borrow(1000e6);
    }

    function test_revert_borrow_insufficientLiquidity() public {
        // Alice deposits collateral but no liquidity in pool
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        vm.prank(alice);
        vm.expectRevert(LendingPool.LendingPool__InsufficientLiquidity.selector);
        lendingPool.borrow(1000e6);
    }

    /*//////////////////////////////////////////////////////////////
                             REPAY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_repay() public {
        // Setup: borrow first
        _provideLiquidity(bob, 50_000e6);

        // 100e18 tokens at $0.60 = $60, LTV 60% = max $36 borrow
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        uint256 borrowAmount = 30e6; // Borrow $30 (under $36 max)
        vm.prank(alice);
        lendingPool.borrow(borrowAmount);

        // Repay
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), borrowAmount);
        lendingPool.repay(borrowAmount);
        vm.stopPrank();

        assertEq(lendingPool.debtOf(alice), 0);
    }

    function test_repay_partial() public {
        _provideLiquidity(bob, 50_000e6);

        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        uint256 borrowAmount = 30e6; // $30 (under $36 max)
        vm.prank(alice);
        lendingPool.borrow(borrowAmount);

        // Partial repay
        uint256 repayAmount = 15e6;
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), repayAmount);
        lendingPool.repay(repayAmount);
        vm.stopPrank();

        assertGt(lendingPool.debtOf(alice), 0);
        assertLt(lendingPool.debtOf(alice), borrowAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTEREST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_interestAccrual() public {
        _provideLiquidity(bob, 50_000e6);

        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        uint256 borrowAmount = 30e6; // $30 (under $36 max)
        vm.prank(alice);
        lendingPool.borrow(borrowAmount);

        uint256 debtBefore = lendingPool.debtOf(alice);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 debtAfter = lendingPool.debtOf(alice);

        assertGt(debtAfter, debtBefore, "Interest should accrue");
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getUtilizationRate() public {
        assertEq(lendingPool.getUtilizationRate(), 0);

        _provideLiquidity(bob, 60e6); // $60 liquidity
        assertEq(lendingPool.getUtilizationRate(), 0); // No borrows yet

        // Setup borrow: 100 tokens at $0.60 = $60 collateral, max borrow = $36
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        vm.prank(alice);
        lendingPool.borrow(30e6); // Borrow $30

        // 30/60 = 50% utilization
        assertEq(lendingPool.getUtilizationRate(), 0.5e18);
    }
}
