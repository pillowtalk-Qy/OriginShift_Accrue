// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.sol";
import {PositionVault} from "../../src/core/PositionVault.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";

contract LiquidationEngineTest is BaseTest {
    PositionVault public vault;

    function setUp() public override {
        super.setUp();
        vault = PositionVault(_createAndConfigureVault(POSITION_ID_YES, "PolyLend YES", "pYES"));

        // Setup: provide liquidity and create a position
        _provideLiquidity(bob, 100_000e6);
    }

    function _setupLiquidatablePosition() internal returns (uint256 borrowAmount) {
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        // Borrow max
        borrowAmount = collateralManager.getMaxBorrowAmount(alice);
        vm.prank(alice);
        lendingPool.borrow(borrowAmount);

        // Price drops 50% to make position liquidatable
        vm.prank(owner);
        priceOracle.setPrice(address(vault), DEFAULT_PRICE / 2);
    }

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_liquidate() public {
        uint256 borrowAmount = _setupLiquidatablePosition();

        // Verify position is liquidatable
        assertTrue(collateralManager.isLiquidatable(alice));

        // Get liquidation info
        (uint256 maxRepay, uint256 collateralToReceive) =
            liquidationEngine.getLiquidationInfo(alice, address(vault));

        assertGt(maxRepay, 0);
        assertGt(collateralToReceive, 0);

        // Liquidator approves and liquidates
        uint256 debtToRepay = maxRepay / 2; // Repay half of max
        
        vm.startPrank(liquidator);
        usdc.approve(address(liquidationEngine), debtToRepay);

        uint256 liquidatorCollateralBefore = vault.balanceOf(liquidator);
        uint256 liquidatorUsdcBefore = usdc.balanceOf(liquidator);

        uint256 collateralSeized = liquidationEngine.liquidate(alice, address(vault), debtToRepay);

        uint256 liquidatorCollateralAfter = vault.balanceOf(liquidator);
        uint256 liquidatorUsdcAfter = usdc.balanceOf(liquidator);
        vm.stopPrank();

        // Verify liquidator received collateral
        assertEq(liquidatorCollateralAfter - liquidatorCollateralBefore, collateralSeized);

        // Verify USDC was spent
        assertEq(liquidatorUsdcBefore - liquidatorUsdcAfter, debtToRepay);

        // Verify debt was reduced
        assertLt(lendingPool.debtOf(alice), borrowAmount);
    }

    function test_revert_liquidate_notLiquidatable() public {
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        // Borrow only 50% of max (healthy position)
        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);
        vm.prank(alice);
        lendingPool.borrow(maxBorrow / 2);

        // Verify not liquidatable
        assertFalse(collateralManager.isLiquidatable(alice));

        // Try to liquidate
        vm.startPrank(liquidator);
        usdc.approve(address(liquidationEngine), 1000e6);

        vm.expectRevert(LiquidationEngine.LiquidationEngine__NotLiquidatable.selector);
        liquidationEngine.liquidate(alice, address(vault), 1000e6);
        vm.stopPrank();
    }

    function test_revert_liquidate_exceedsCloseAmount() public {
        uint256 borrowAmount = _setupLiquidatablePosition();

        // Try to repay more than close factor allows
        uint256 closeFactor = liquidationEngine.closeFactor();
        uint256 maxRepay = (borrowAmount * closeFactor) / 10000;

        vm.startPrank(liquidator);
        usdc.approve(address(liquidationEngine), maxRepay * 2);

        vm.expectRevert(LiquidationEngine.LiquidationEngine__ExceedsCloseAmount.selector);
        liquidationEngine.liquidate(alice, address(vault), maxRepay * 2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getLiquidationInfo() public {
        _setupLiquidatablePosition();

        (uint256 maxDebtToRepay, uint256 collateralToReceive) =
            liquidationEngine.getLiquidationInfo(alice, address(vault));

        assertGt(maxDebtToRepay, 0);
        assertGt(collateralToReceive, 0);
    }

    function test_getLiquidationInfo_notLiquidatable() public {
        uint256 collateralAmount = 100e18;
        _depositToVault(alice, address(vault), POSITION_ID_YES, collateralAmount);
        _depositCollateral(alice, address(vault), collateralAmount);

        (uint256 maxDebtToRepay, uint256 collateralToReceive) =
            liquidationEngine.getLiquidationInfo(alice, address(vault));

        assertEq(maxDebtToRepay, 0);
        assertEq(collateralToReceive, 0);
    }

    function test_calculateCollateralToSeize() public view {
        uint256 debtToRepay = 1000e6; // $1000

        uint256 collateralToSeize = liquidationEngine.calculateCollateralToSeize(address(vault), debtToRepay);

        // At $0.60 per token with 5% bonus:
        // Value to seize = $1000 * 1.05 = $1050
        // Tokens = $1050 / $0.60 = 1750 tokens
        // In 18 decimals = 1750e18
        assertApproxEqRel(collateralToSeize, 1750e18, 0.01e18);
    }

    function test_canLiquidate() public {
        _setupLiquidatablePosition();
        assertTrue(liquidationEngine.canLiquidate(alice));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setCloseFactor() public {
        vm.prank(owner);
        liquidationEngine.setCloseFactor(7500); // 75%

        assertEq(liquidationEngine.closeFactor(), 7500);
    }

    function test_revert_setCloseFactor_invalid() public {
        vm.prank(owner);
        vm.expectRevert("Invalid close factor");
        liquidationEngine.setCloseFactor(15000); // > 100%
    }
}
