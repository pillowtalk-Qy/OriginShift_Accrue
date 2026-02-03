// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {PositionVault} from "../src/core/PositionVault.sol";
import {PositionVaultFactory} from "../src/core/PositionVaultFactory.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {LiquidationEngine} from "../src/core/LiquidationEngine.sol";
import {InterestRateModel} from "../src/core/InterestRateModel.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";

/// @title BaseTest
/// @notice Base test contract with common setup for all PolyLend tests
abstract contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    // Core contracts
    PositionVaultFactory public factory;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    LiquidationEngine public liquidationEngine;
    InterestRateModel public interestRateModel;
    PriceOracle public priceOracle;

    // Mock tokens
    MockERC20 public usdc;
    MockERC1155 public ctf;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant POSITION_ID_YES = 1;
    uint256 public constant POSITION_ID_NO = 2;

    uint256 public constant INITIAL_CTF_BALANCE = 1000e18;
    uint256 public constant INITIAL_USDC_BALANCE = 100_000e6;

    // Price: $0.60 per position token (8 decimals)
    uint256 public constant DEFAULT_PRICE = 60_000_000; // $0.60

    // LTV parameters (basis points)
    uint256 public constant LTV = 6000; // 60%
    uint256 public constant LIQUIDATION_THRESHOLD = 7500; // 75%
    uint256 public constant LIQUIDATION_BONUS = 500; // 5%

    /*//////////////////////////////////////////////////////////////
                                 USERS
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public alice;
    address public bob;
    address public liquidator;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        liquidator = makeAddr("liquidator");

        vm.startPrank(owner);

        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        ctf = new MockERC1155();

        // Deploy core contracts
        interestRateModel = new InterestRateModel(owner);
        priceOracle = new PriceOracle(owner);
        factory = new PositionVaultFactory(address(ctf), owner);

        // Deploy LendingPool (needs InterestRateModel)
        lendingPool = new LendingPool(address(usdc), address(interestRateModel), owner);

        // Deploy CollateralManager (needs LendingPool and PriceOracle)
        collateralManager = new CollateralManager(address(lendingPool), address(priceOracle), owner);

        // Deploy LiquidationEngine
        liquidationEngine =
            new LiquidationEngine(address(lendingPool), address(collateralManager), address(priceOracle), owner);

        // Connect contracts
        lendingPool.setCollateralManager(address(collateralManager));
        collateralManager.setLiquidationEngine(address(liquidationEngine));

        vm.stopPrank();

        // Setup initial balances
        _setupBalances();
    }

    function _setupBalances() internal {
        // Mint CTF tokens to users
        ctf.mint(alice, POSITION_ID_YES, INITIAL_CTF_BALANCE);
        ctf.mint(alice, POSITION_ID_NO, INITIAL_CTF_BALANCE);
        ctf.mint(bob, POSITION_ID_YES, INITIAL_CTF_BALANCE);
        ctf.mint(bob, POSITION_ID_NO, INITIAL_CTF_BALANCE);

        // Mint USDC to users
        usdc.mint(alice, INITIAL_USDC_BALANCE);
        usdc.mint(bob, INITIAL_USDC_BALANCE);
        usdc.mint(liquidator, INITIAL_USDC_BALANCE * 10);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a vault and configure it as collateral
    function _createAndConfigureVault(uint256 positionId, string memory name, string memory symbol)
        internal
        returns (address vault)
    {
        vm.startPrank(owner);

        vault = factory.createVault(positionId, name, symbol);

        // Set price
        priceOracle.setPrice(vault, DEFAULT_PRICE);

        // Configure as collateral
        collateralManager.setCollateralConfig(vault, LTV, LIQUIDATION_THRESHOLD, LIQUIDATION_BONUS);

        vm.stopPrank();
    }

    /// @notice Deposit CTF into vault and get shares
    function _depositToVault(address user, address vault, uint256 positionId, uint256 amount)
        internal
        returns (uint256 shares)
    {
        vm.startPrank(user);
        ctf.setApprovalForAll(vault, true);
        shares = PositionVault(vault).deposit(amount, user);
        vm.stopPrank();
    }

    /// @notice Deposit collateral for a user
    function _depositCollateral(address user, address vault, uint256 amount) internal {
        vm.startPrank(user);
        PositionVault(vault).approve(address(collateralManager), amount);
        collateralManager.depositCollateral(vault, amount);
        vm.stopPrank();
    }

    /// @notice Provide liquidity to the lending pool
    function _provideLiquidity(address lender, uint256 amount) internal {
        vm.startPrank(lender);
        usdc.approve(address(lendingPool), amount);
        lendingPool.deposit(amount);
        vm.stopPrank();
    }
}
