// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.sol";
import {PositionVault} from "../../src/core/PositionVault.sol";
import {CollateralManager} from "../../src/core/CollateralManager.sol";

contract CollateralManagerTest is BaseTest {
    PositionVault public vault;

    function setUp() public override {
        super.setUp();
        vault = PositionVault(_createAndConfigureVault(POSITION_ID_YES, "PolyLend YES", "pYES"));
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_depositCollateral() public {
        uint256 amount = 100e18;

        // First deposit to vault to get shares
        _depositToVault(alice, address(vault), POSITION_ID_YES, amount);

        // Then deposit as collateral
        vm.startPrank(alice);
        vault.approve(address(collateralManager), amount);
        collateralManager.depositCollateral(address(vault), amount);
        vm.stopPrank();

        assertEq(collateralManager.getCollateralAmount(alice, address(vault)), amount);
    }

    function test_depositCollateral_multiple() public {
        uint256 amount1 = 50e18;
        uint256 amount2 = 30e18;

        _depositToVault(alice, address(vault), POSITION_ID_YES, amount1 + amount2);

        vm.startPrank(alice);
        vault.approve(address(collateralManager), amount1 + amount2);
        collateralManager.depositCollateral(address(vault), amount1);
        collateralManager.depositCollateral(address(vault), amount2);
        vm.stopPrank();

        assertEq(collateralManager.getCollateralAmount(alice, address(vault)), amount1 + amount2);
    }

    function test_revert_depositCollateral_notActive() public {
        // Create a vault without configuring it as collateral
        address unconfiguredVault = factory.createVault(999, "Unconfigured", "UNC");

        ctf.mint(alice, 999, 100e18);
        vm.startPrank(alice);
        ctf.setApprovalForAll(unconfiguredVault, true);
        PositionVault(unconfiguredVault).deposit(100e18, alice);

        PositionVault(unconfiguredVault).approve(address(collateralManager), 100e18);

        vm.expectRevert(CollateralManager.CollateralManager__CollateralNotActive.selector);
        collateralManager.depositCollateral(unconfiguredVault, 100e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                       WITHDRAW COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawCollateral() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        _depositToVault(alice, address(vault), POSITION_ID_YES, depositAmount);
        _depositCollateral(alice, address(vault), depositAmount);

        vm.prank(alice);
        collateralManager.withdrawCollateral(address(vault), withdrawAmount);

        assertEq(collateralManager.getCollateralAmount(alice, address(vault)), depositAmount - withdrawAmount);
    }

    function test_revert_withdrawCollateral_wouldBeLiquidatable() public {
        // Setup: deposit collateral and borrow
        _provideLiquidity(bob, 50_000e6);

        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        // Borrow close to max
        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);
        vm.prank(alice);
        lendingPool.borrow(maxBorrow * 90 / 100); // Borrow 90% of max

        // Try to withdraw most collateral (should fail)
        vm.prank(alice);
        vm.expectRevert(CollateralManager.CollateralManager__WouldBeLiquidatable.selector);
        collateralManager.withdrawCollateral(address(vault), collateralAmount * 90 / 100);
    }

    /*//////////////////////////////////////////////////////////////
                         VALUE CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getTotalCollateralValue() public {
        uint256 amount = 100e18;

        _depositToVault(alice, address(vault), POSITION_ID_YES, amount);
        _depositCollateral(alice, address(vault), amount);

        uint256 value = collateralManager.getTotalCollateralValue(alice);

        // 100 tokens * $0.60 = $60 (in 8 decimals = 60_00000000)
        assertEq(value, 60_00000000);
    }

    function test_getMaxBorrowAmount() public {
        uint256 amount = 100e18;

        _depositToVault(alice, address(vault), POSITION_ID_YES, amount);
        _depositCollateral(alice, address(vault), amount);

        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);

        // Collateral value = $60, LTV = 60%, max borrow = $36
        // In USDC (6 decimals) = 36_000000
        assertEq(maxBorrow, 36_000000);
    }

    /*//////////////////////////////////////////////////////////////
                          HEALTH FACTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getHealthFactor_noDebt() public {
        uint256 amount = 100e18;

        _depositToVault(alice, address(vault), POSITION_ID_YES, amount);
        _depositCollateral(alice, address(vault), amount);

        uint256 healthFactor = collateralManager.getHealthFactor(alice);

        assertEq(healthFactor, type(uint256).max); // Infinite health with no debt
    }

    function test_getHealthFactor_withDebt() public {
        _provideLiquidity(bob, 50_000e6);

        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        // Borrow $30 (half of max $36)
        vm.prank(alice);
        lendingPool.borrow(30_000000);

        uint256 healthFactor = collateralManager.getHealthFactor(alice);

        // Adjusted collateral = $60 * 0.75 = $45
        // Debt = $30
        // Health factor = $45 / $30 = 1.5e18
        assertApproxEqRel(healthFactor, 1.5e18, 0.01e18); // Within 1%
    }

    function test_isLiquidatable() public {
        _provideLiquidity(bob, 50_000e6);

        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        // Borrow max
        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);
        vm.prank(alice);
        lendingPool.borrow(maxBorrow);

        // Not liquidatable yet
        assertFalse(collateralManager.isLiquidatable(alice));

        // Price drops 50%
        vm.prank(owner);
        priceOracle.setPrice(address(vault), DEFAULT_PRICE / 2);

        // Now liquidatable
        assertTrue(collateralManager.isLiquidatable(alice));
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setCollateralConfig() public {
        address newVault = factory.createVault(100, "Test", "TST");

        vm.prank(owner);
        collateralManager.setCollateralConfig(newVault, 5000, 7000, 1000);

        CollateralManager.CollateralConfig memory config = collateralManager.getCollateralConfig(newVault);

        assertTrue(config.isActive);
        assertEq(config.ltv, 5000);
        assertEq(config.liquidationThreshold, 7000);
        assertEq(config.liquidationBonus, 1000);
    }

    function test_revert_setCollateralConfig_invalidLtv() public {
        address newVault = factory.createVault(100, "Test", "TST");

        vm.prank(owner);
        vm.expectRevert(CollateralManager.CollateralManager__InvalidConfig.selector);
        collateralManager.setCollateralConfig(newVault, 8000, 7000, 500); // LTV > threshold
    }
}
