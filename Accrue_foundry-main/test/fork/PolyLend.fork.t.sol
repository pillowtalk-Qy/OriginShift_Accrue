// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {PositionVault} from "../../src/core/PositionVault.sol";
import {PositionVaultFactory} from "../../src/core/PositionVaultFactory.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {CollateralManager} from "../../src/core/CollateralManager.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";

/*//////////////////////////////////////////////////////////////
                          MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Mock USDC for Amoy testnet
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Mock CTF (Conditional Token Framework) for Amoy testnet
contract MockCTF is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

/*//////////////////////////////////////////////////////////////
                          FORK TEST
//////////////////////////////////////////////////////////////*/

/// @title PolyLendAmoyForkTest
/// @notice Fork test for Polygon Amoy testnet
/// @dev Uses mock contracts since Polymarket is not on Amoy
contract PolyLendAmoyForkTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    MockUSDC public usdc;
    MockCTF public ctf;

    PositionVaultFactory public factory;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    LiquidationEngine public liquidationEngine;
    InterestRateModel public interestRateModel;
    PriceOracle public priceOracle;
    PositionVault public vault;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant POSITION_ID_YES = 1;
    uint256 constant POSITION_ID_NO = 2;

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

    function setUp() public {
        // Create users
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        liquidator = makeAddr("liquidator");

        vm.startPrank(owner);

        // Deploy mock tokens
        usdc = new MockUSDC();
        ctf = new MockCTF();

        console2.log("=== Deployed Mock Contracts ===");
        console2.log("Mock USDC:", address(usdc));
        console2.log("Mock CTF:", address(ctf));

        // Deploy PolyLend protocol
        interestRateModel = new InterestRateModel(owner);
        priceOracle = new PriceOracle(owner);
        factory = new PositionVaultFactory(address(ctf), owner);
        lendingPool = new LendingPool(address(usdc), address(interestRateModel), owner);
        collateralManager = new CollateralManager(address(lendingPool), address(priceOracle), owner);
        liquidationEngine = new LiquidationEngine(
            address(lendingPool), address(collateralManager), address(priceOracle), owner
        );

        // Connect contracts
        lendingPool.setCollateralManager(address(collateralManager));
        collateralManager.setLiquidationEngine(address(liquidationEngine));

        // Create vaults for YES/NO positions
        address vaultYes = factory.createVault(POSITION_ID_YES, "BTC 100k YES", "pBTC100kY");
        address vaultNo = factory.createVault(POSITION_ID_NO, "BTC 100k NO", "pBTC100kN");
        vault = PositionVault(vaultYes);

        // Configure collateral: 60% LTV, 75% liquidation threshold, 5% bonus
        priceOracle.setPrice(vaultYes, 60_000_000); // $0.60
        priceOracle.setPrice(vaultNo, 40_000_000);  // $0.40
        collateralManager.setCollateralConfig(vaultYes, 6000, 7500, 500);
        collateralManager.setCollateralConfig(vaultNo, 6000, 7500, 500);

        console2.log("\n=== Deployed PolyLend Protocol ===");
        console2.log("InterestRateModel:", address(interestRateModel));
        console2.log("PriceOracle:", address(priceOracle));
        console2.log("PositionVaultFactory:", address(factory));
        console2.log("LendingPool:", address(lendingPool));
        console2.log("CollateralManager:", address(collateralManager));
        console2.log("LiquidationEngine:", address(liquidationEngine));
        console2.log("Vault YES:", vaultYes);
        console2.log("Vault NO:", vaultNo);

        vm.stopPrank();

        // Fund test users
        _fundUsers();
    }

    function _fundUsers() internal {
        // Mint USDC to users
        usdc.mint(alice, 100_000e6);
        usdc.mint(bob, 100_000e6);
        usdc.mint(liquidator, 1_000_000e6);

        // Mint CTF tokens to users
        ctf.mint(alice, POSITION_ID_YES, 1000e18);
        ctf.mint(alice, POSITION_ID_NO, 1000e18);
        ctf.mint(bob, POSITION_ID_YES, 1000e18);
        ctf.mint(bob, POSITION_ID_NO, 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                          DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_amoy_deploymentSuccessful() public view {
        assertEq(factory.ctf(), address(ctf));
        assertEq(lendingPool.asset(), address(usdc));
        assertEq(factory.getVaultCount(), 2);

        console2.log("\n=== Deployment Verification ===");
        console2.log("Factory CTF:", factory.ctf());
        console2.log("LendingPool Asset:", lendingPool.asset());
        console2.log("Vault Count:", factory.getVaultCount());
    }

    /*//////////////////////////////////////////////////////////////
                          LENDER FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_amoy_lenderFlow() public {
        console2.log("\n=== Lender Flow Test ===");

        uint256 depositAmount = 10_000e6;

        // Alice deposits USDC
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), depositAmount);
        uint256 shares = lendingPool.deposit(depositAmount);
        vm.stopPrank();

        console2.log("Alice deposited:", depositAmount / 1e6, "USDC");
        console2.log("Alice received shares:", shares);
        console2.log("Pool total deposits:", lendingPool.totalDeposits() / 1e6, "USDC");

        assertEq(lendingPool.sharesOf(alice), shares);

        // Withdraw
        vm.startPrank(alice);
        uint256 withdrawn = lendingPool.withdraw(shares);
        vm.stopPrank();

        console2.log("Alice withdrew:", withdrawn / 1e6, "USDC");
        assertEq(lendingPool.sharesOf(alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        BORROWER FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_amoy_borrowerFlow() public {
        console2.log("\n=== Borrower Flow Test ===");

        // Bob provides liquidity
        vm.startPrank(bob);
        usdc.approve(address(lendingPool), 50_000e6);
        lendingPool.deposit(50_000e6);
        vm.stopPrank();
        console2.log("Bob provided 50,000 USDC liquidity");

        // Alice deposits CTF as collateral
        uint256 collateralAmount = 100e18;
        vm.startPrank(alice);

        // 1. Deposit CTF to vault
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(collateralAmount, alice);
        console2.log("Alice deposited", collateralAmount / 1e18, "CTF to vault");

        // 2. Deposit vault shares as collateral
        vault.approve(address(collateralManager), collateralAmount);
        collateralManager.depositCollateral(address(vault), collateralAmount);
        console2.log("Alice deposited collateral");

        // Check max borrow
        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);
        console2.log("Alice max borrow:", maxBorrow / 1e6, "USDC");

        // 3. Borrow USDC
        uint256 borrowAmount = 30e6; // $30
        lendingPool.borrow(borrowAmount);
        console2.log("Alice borrowed:", borrowAmount / 1e6, "USDC");

        // Check health factor
        uint256 healthFactor = collateralManager.getHealthFactor(alice);
        console2.log("Alice health factor:", healthFactor * 100 / 1e18, "%");

        // 4. Repay
        usdc.approve(address(lendingPool), borrowAmount);
        lendingPool.repay(borrowAmount);
        console2.log("Alice repaid:", borrowAmount / 1e6, "USDC");

        // 5. Withdraw collateral
        collateralManager.withdrawCollateral(address(vault), collateralAmount);
        console2.log("Alice withdrew collateral");

        // 6. Withdraw CTF
        vault.withdraw(collateralAmount, alice);
        console2.log("Alice withdrew CTF from vault");

        vm.stopPrank();

        assertEq(lendingPool.debtOf(alice), 0);
        assertEq(collateralManager.getCollateralAmount(alice, address(vault)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDATION FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_amoy_liquidationFlow() public {
        console2.log("\n=== Liquidation Flow Test ===");

        // Bob provides liquidity
        vm.startPrank(bob);
        usdc.approve(address(lendingPool), 50_000e6);
        lendingPool.deposit(50_000e6);
        vm.stopPrank();

        // Alice deposits collateral and borrows max
        uint256 collateralAmount = 100e18;
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(collateralAmount, alice);
        vault.approve(address(collateralManager), collateralAmount);
        collateralManager.depositCollateral(address(vault), collateralAmount);

        uint256 maxBorrow = collateralManager.getMaxBorrowAmount(alice);
        lendingPool.borrow(maxBorrow);
        vm.stopPrank();

        console2.log("Alice borrowed max:", maxBorrow / 1e6, "USDC");
        console2.log("Health factor before:", collateralManager.getHealthFactor(alice) * 100 / 1e18, "%");

        // Price drops 50% - position becomes liquidatable
        vm.prank(owner);
        priceOracle.setPrice(address(vault), 30_000_000); // $0.30
        console2.log("Price dropped to $0.30");

        uint256 healthFactorAfter = collateralManager.getHealthFactor(alice);
        console2.log("Health factor after:", healthFactorAfter * 100 / 1e18, "%");
        assertTrue(collateralManager.isLiquidatable(alice));
        console2.log("Alice is now liquidatable!");

        // Liquidator liquidates
        vm.startPrank(liquidator);
        (uint256 maxRepay, uint256 collateralToReceive) = liquidationEngine.getLiquidationInfo(alice, address(vault));
        console2.log("Max debt to repay:", maxRepay / 1e6, "USDC");
        console2.log("Collateral to receive:", collateralToReceive / 1e18, "tokens");

        usdc.approve(address(liquidationEngine), maxRepay);
        uint256 seized = liquidationEngine.liquidate(alice, address(vault), maxRepay);
        vm.stopPrank();

        console2.log("Liquidator seized:", seized / 1e18, "collateral tokens");
        console2.log("Alice remaining debt:", lendingPool.debtOf(alice) / 1e6, "USDC");
    }

    /*//////////////////////////////////////////////////////////////
                          INTEREST RATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_amoy_interestRates() public {
        console2.log("\n=== Interest Rate Test ===");

        // Deposit liquidity
        vm.startPrank(bob);
        usdc.approve(address(lendingPool), 100_000e6);
        lendingPool.deposit(100_000e6);
        vm.stopPrank();

        console2.log("Initial utilization:", lendingPool.getUtilizationRate() * 100 / 1e18, "%");

        // Alice borrows to create utilization
        // 500e18 tokens * $0.60 = $300 collateral, 60% LTV = $180 max borrow
        uint256 collateralAmount = 500e18;
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(collateralAmount, alice);
        vault.approve(address(collateralManager), collateralAmount);
        collateralManager.depositCollateral(address(vault), collateralAmount);
        lendingPool.borrow(150e6); // Borrow $150 (within $180 limit)
        vm.stopPrank();

        uint256 utilization = lendingPool.getUtilizationRate();
        console2.log("After borrow utilization:", utilization * 100 / 1e18, "%");

        (uint256 annualBorrow, uint256 annualDeposit) = interestRateModel.getAnnualRates(utilization);
        console2.log("Annual borrow APY:", annualBorrow * 100 / 1e18, "%");
        console2.log("Annual deposit APY:", annualDeposit * 100 / 1e18, "%");

        // Time passes
        vm.warp(block.timestamp + 365 days);

        uint256 debt = lendingPool.debtOf(alice);
        console2.log("Alice debt after 1 year:", debt / 1e6, "USDC");
        console2.log("Interest accrued:", (debt - 150e6) / 1e6, "USDC");
    }

    /*//////////////////////////////////////////////////////////////
                          PROTOCOL STATS
    //////////////////////////////////////////////////////////////*/

    function test_amoy_protocolStats() public {
        console2.log("\n=== Protocol Stats ===");

        // Setup some activity
        vm.startPrank(bob);
        usdc.approve(address(lendingPool), 50_000e6);
        lendingPool.deposit(50_000e6);
        vm.stopPrank();

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(100e18, alice);
        vault.approve(address(collateralManager), 100e18);
        collateralManager.depositCollateral(address(vault), 100e18);
        lendingPool.borrow(30e6);
        vm.stopPrank();

        console2.log("Total Deposits:", lendingPool.totalDeposits() / 1e6, "USDC");
        console2.log("Total Borrows:", lendingPool.totalBorrows() / 1e6, "USDC");
        console2.log("Available Liquidity:", lendingPool.availableLiquidity() / 1e6, "USDC");
        console2.log("Utilization Rate:", lendingPool.getUtilizationRate() * 100 / 1e18, "%");
        console2.log("Vault Count:", factory.getVaultCount());

        address[] memory vaults = factory.getAllVaults();
        for (uint256 i = 0; i < vaults.length; i++) {
            PositionVault v = PositionVault(vaults[i]);
            console2.log("---");
            console2.log("Vault", i, ":", vaults[i]);
            console2.log("  Name:", v.name());
            console2.log("  Total Assets:", v.totalAssets() / 1e18);
            (uint256 price,,) = priceOracle.getPriceData(vaults[i]);
            console2.log("  Price: $", price / 1e6);
        }
    }
}
