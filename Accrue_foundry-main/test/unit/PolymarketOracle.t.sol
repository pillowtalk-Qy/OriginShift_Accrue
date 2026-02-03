// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";

/// @title PriceOracleTest
/// @notice Unit tests for PriceOracle contract
contract PriceOracleTest is BaseTest {
    address public vault;

    function setUp() public override {
        super.setUp();

        // Create a vault for testing
        vm.prank(owner);
        vault = factory.createVault(POSITION_ID_YES, "Price YES", "pYES");
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(priceOracle.owner(), owner);
        assertEq(priceOracle.decimals(), 8);
        assertEq(priceOracle.maxStaleness(), 1 days);
    }

    /*//////////////////////////////////////////////////////////////
                            SET PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setPrice() public {
        uint256 price = 60_000_000; // $0.60 (8 decimals)

        vm.prank(owner);
        priceOracle.setPrice(vault, price);

        (uint256 storedPrice, uint256 lastUpdated, bool isValid) = priceOracle.getPriceData(vault);

        assertEq(storedPrice, price);
        assertEq(lastUpdated, block.timestamp);
        assertTrue(isValid);
    }

    function test_setPrice_emitsEvent() public {
        uint256 price = 60_000_000; // $0.60

        vm.expectEmit(true, false, false, true);
        emit IPriceOracle.PriceUpdated(vault, 0, price, block.timestamp);

        vm.prank(owner);
        priceOracle.setPrice(vault, price);
    }

    function test_revert_setPrice_notOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        priceOracle.setPrice(vault, 60_000_000);
    }

    function test_revert_setPrice_zeroPrice() public {
        vm.prank(owner);
        vm.expectRevert(PriceOracle.PriceOracle__InvalidPrice.selector);
        priceOracle.setPrice(vault, 0);
    }

    function test_setPrices_batch() public {
        vm.prank(owner);
        address vault2 = factory.createVault(POSITION_ID_NO, "Price NO", "pNO");

        address[] memory vaults = new address[](2);
        vaults[0] = vault;
        vaults[1] = vault2;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 60_000_000; // $0.60
        prices[1] = 40_000_000; // $0.40

        vm.prank(owner);
        priceOracle.setPrices(vaults, prices);

        (uint256 price1,,) = priceOracle.getPriceData(vault);
        (uint256 price2,,) = priceOracle.getPriceData(vault2);

        assertEq(price1, 60_000_000);
        assertEq(price2, 40_000_000);
    }

    /*//////////////////////////////////////////////////////////////
                          GET ASSET VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAssetValue() public {
        uint256 price = 60_000_000; // $0.60 per position token (8 decimals)

        vm.prank(owner);
        priceOracle.setPrice(vault, price);

        // 100 position tokens (18 decimals) should return $60 (8 decimals)
        uint256 amount = 100e18;
        uint256 value = priceOracle.getAssetValue(vault, amount);

        // value = amount * price / 1e18 = 100e18 * 60_000_000 / 1e18 = 60_000_000_00 = $60.00
        assertEq(value, 60_00000000); // $60 in 8 decimals
    }

    function test_getAssetValue_fractional() public {
        uint256 price = 75_000_000; // $0.75 per position token

        vm.prank(owner);
        priceOracle.setPrice(vault, price);

        uint256 amount = 1e18; // 1 position token
        uint256 value = priceOracle.getAssetValue(vault, amount);

        assertEq(value, 75_000_000); // $0.75
    }

    function test_revert_getAssetValue_priceNotSet() public {
        vm.expectRevert(PriceOracle.PriceOracle__PriceNotSet.selector);
        priceOracle.getAssetValue(vault, 100e18);
    }

    function test_revert_getAssetValue_stalePrice() public {
        vm.prank(owner);
        priceOracle.setPrice(vault, 60_000_000);

        // Fast forward beyond staleness threshold
        vm.warp(block.timestamp + 1 days + 1);

        vm.expectRevert(PriceOracle.PriceOracle__StalePrice.selector);
        priceOracle.getAssetValue(vault, 100e18);
    }

    function test_revert_getAssetValue_invalidatedPrice() public {
        vm.startPrank(owner);
        priceOracle.setPrice(vault, 60_000_000);
        priceOracle.invalidatePrice(vault);
        vm.stopPrank();

        vm.expectRevert(PriceOracle.PriceOracle__PriceNotSet.selector);
        priceOracle.getAssetValue(vault, 100e18);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setMaxStaleness() public {
        vm.prank(owner);
        priceOracle.setMaxStaleness(2 days);

        assertEq(priceOracle.maxStaleness(), 2 days);
    }

    function test_invalidatePrice() public {
        vm.startPrank(owner);
        priceOracle.setPrice(vault, 60_000_000);
        priceOracle.invalidatePrice(vault);
        vm.stopPrank();

        (,, bool isValid) = priceOracle.getPriceData(vault);
        assertFalse(isValid);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isPriceValid() public {
        vm.prank(owner);
        priceOracle.setPrice(vault, 60_000_000);

        assertTrue(priceOracle.isPriceValid(vault));

        // Fast forward
        vm.warp(block.timestamp + 1 days + 1);
        assertFalse(priceOracle.isPriceValid(vault));
    }

    function test_isPriceValid_invalidated() public {
        vm.startPrank(owner);
        priceOracle.setPrice(vault, 60_000_000);
        priceOracle.invalidatePrice(vault);
        vm.stopPrank();

        assertFalse(priceOracle.isPriceValid(vault));
    }

    function test_getPrice() public {
        uint256 price = 60_000_000;

        vm.prank(owner);
        priceOracle.setPrice(vault, price);

        assertEq(priceOracle.getPrice(vault), price);
    }

    function test_revert_getPrice_notSet() public {
        vm.expectRevert(PriceOracle.PriceOracle__PriceNotSet.selector);
        priceOracle.getPrice(vault);
    }

    function test_decimals() public view {
        assertEq(priceOracle.decimals(), 8);
    }

    /*//////////////////////////////////////////////////////////////
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getAssetValue(uint256 price, uint256 amount) public {
        price = bound(price, 1, 1e8); // 0.00000001 to $1.00
        amount = bound(amount, 1e18, 1_000_000e18);

        vm.prank(owner);
        priceOracle.setPrice(vault, price);

        uint256 value = priceOracle.getAssetValue(vault, amount);

        // value = amount * price / 1e18
        uint256 expected = (amount * price) / 1e18;
        assertEq(value, expected);
    }
}
