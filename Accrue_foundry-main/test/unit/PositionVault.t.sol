// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.sol";
import {PositionVault} from "../../src/core/PositionVault.sol";

contract PositionVaultTest is BaseTest {
    PositionVault public vault;

    function setUp() public override {
        super.setUp();
        vault = PositionVault(_createAndConfigureVault(POSITION_ID_YES, "PolyLend YES", "pYES"));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(vault.name(), "PolyLend YES");
        assertEq(vault.symbol(), "pYES");
        assertEq(vault.positionId(), POSITION_ID_YES);
        assertEq(address(vault.ctf()), address(ctf));
        assertEq(vault.factory(), address(factory));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deposit() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);

        uint256 ctfBefore = ctf.balanceOf(alice, POSITION_ID_YES);
        uint256 sharesBefore = vault.balanceOf(alice);

        vault.deposit(depositAmount, alice);

        uint256 ctfAfter = ctf.balanceOf(alice, POSITION_ID_YES);
        uint256 sharesAfter = vault.balanceOf(alice);
        vm.stopPrank();

        assertEq(ctfBefore - ctfAfter, depositAmount, "CTF not transferred");
        assertEq(sharesAfter - sharesBefore, depositAmount, "Shares not minted (1:1)");
        assertEq(vault.totalAssets(), depositAmount, "Total assets mismatch");
    }

    function test_deposit_toOther() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, bob);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), depositAmount);
    }

    function test_revert_deposit_zeroAmount() public {
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);

        vm.expectRevert(PositionVault.PositionVault__InvalidAmount.selector);
        vault.deposit(0, alice);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdraw() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        // First deposit
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);

        uint256 ctfBefore = ctf.balanceOf(alice, POSITION_ID_YES);
        vault.withdraw(withdrawAmount, alice);
        uint256 ctfAfter = ctf.balanceOf(alice, POSITION_ID_YES);
        vm.stopPrank();

        assertEq(ctfAfter - ctfBefore, withdrawAmount, "CTF not returned");
        assertEq(vault.balanceOf(alice), depositAmount - withdrawAmount);
    }

    function test_withdraw_full() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);
        vault.withdraw(depositAmount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function test_revert_withdraw_insufficientShares() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);

        vm.expectRevert();
        vault.withdraw(depositAmount + 1, alice);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          ERC1155 RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_revert_receiveWrongPositionId() public {
        uint256 wrongId = 999;
        ctf.mint(alice, wrongId, 100e18);

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);

        vm.expectRevert(PositionVault.PositionVault__InvalidPositionId.selector);
        ctf.safeTransferFrom(alice, address(vault), wrongId, 100e18, "");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_deposit(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_CTF_BALANCE);

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), amount);
        assertEq(vault.totalAssets(), amount);
    }
}
