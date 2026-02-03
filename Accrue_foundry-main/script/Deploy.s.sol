// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import {PositionVaultFactory} from "../src/core/PositionVaultFactory.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {LiquidationEngine} from "../src/core/LiquidationEngine.sol";
import {InterestRateModel} from "../src/core/InterestRateModel.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import {PolyLendRouter} from "../src/periphery/PolyLendRouter.sol";

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
                    POLYGON AMOY TESTNET DEPLOYMENT
//////////////////////////////////////////////////////////////*/

/// @title DeployAmoy
/// @notice Deployment script for Polygon Amoy testnet
contract DeployAmoy is Script {
    /*//////////////////////////////////////////////////////////////
                            DEPLOYED CONTRACTS
    //////////////////////////////////////////////////////////////*/

    MockUSDC public usdc;
    MockCTF public ctf;

    PositionVaultFactory public factory;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    LiquidationEngine public liquidationEngine;
    InterestRateModel public interestRateModel;
    PriceOracle public priceOracle;
    PolyLendRouter public router;

    function run() external {
        // 使用 --account 或 --private-key 传入的账户
        address deployer = msg.sender;

        console2.log("===========================================");
        console2.log("  PolyLend - Polygon Amoy Testnet Deploy");
        console2.log("===========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        vm.startBroadcast();

        // 1. Deploy mock tokens
        usdc = new MockUSDC();
        ctf = new MockCTF();

        console2.log("[1/9] Mock USDC:", address(usdc));
        console2.log("[2/9] Mock CTF:", address(ctf));

        // 2. Deploy core protocol
        interestRateModel = new InterestRateModel(deployer);
        console2.log("[3/9] InterestRateModel:", address(interestRateModel));

        priceOracle = new PriceOracle(deployer);
        console2.log("[4/9] PriceOracle:", address(priceOracle));

        factory = new PositionVaultFactory(address(ctf), deployer);
        console2.log("[5/9] PositionVaultFactory:", address(factory));

        lendingPool = new LendingPool(address(usdc), address(interestRateModel), deployer);
        console2.log("[6/9] LendingPool:", address(lendingPool));

        collateralManager = new CollateralManager(address(lendingPool), address(priceOracle), deployer);
        console2.log("[7/9] CollateralManager:", address(collateralManager));

        liquidationEngine = new LiquidationEngine(
            address(lendingPool), address(collateralManager), address(priceOracle), deployer
        );
        console2.log("[8/9] LiquidationEngine:", address(liquidationEngine));

        router = new PolyLendRouter(address(factory), address(lendingPool), address(collateralManager));
        console2.log("[9/9] PolyLendRouter:", address(router));

        // 3. Connect contracts
        lendingPool.setCollateralManager(address(collateralManager));
        collateralManager.setLiquidationEngine(address(liquidationEngine));
        console2.log("");
        console2.log("Contracts connected!");

        // 4. Create example vaults
        address vaultYes = factory.createVault(1, "BTC 100k YES", "pBTC100kY");
        address vaultNo = factory.createVault(2, "BTC 100k NO", "pBTC100kN");

        // 5. Configure collateral
        priceOracle.setPrice(vaultYes, 60_000_000); // $0.60
        priceOracle.setPrice(vaultNo, 40_000_000);  // $0.40
        collateralManager.setCollateralConfig(vaultYes, 6000, 7500, 500);
        collateralManager.setCollateralConfig(vaultNo, 6000, 7500, 500);

        console2.log("");
        console2.log("Example Vaults:");
        console2.log("  YES Vault:", vaultYes);
        console2.log("  NO Vault:", vaultNo);

        // 6. Mint test tokens to deployer
        usdc.mint(deployer, 1_000_000e6);  // 1M USDC
        ctf.mint(deployer, 1, 10_000e18);  // 10k YES tokens
        ctf.mint(deployer, 2, 10_000e18);  // 10k NO tokens

        console2.log("");
        console2.log("Minted to deployer:");
        console2.log("  1,000,000 USDC");
        console2.log("  10,000 YES tokens");
        console2.log("  10,000 NO tokens");

        vm.stopBroadcast();

        // Log summary
        _logDeploymentSummary(vaultYes, vaultNo);
    }

    function _logDeploymentSummary(address vaultYes, address vaultNo) internal view {
        console2.log("");
        console2.log("============ DEPLOYMENT COMPLETE ============");
        console2.log("");
        console2.log("Add to frontend .env:");
        console2.log("-------------------------------------------");
        console2.log("NEXT_PUBLIC_USDC_ADDRESS=", address(usdc));
        console2.log("NEXT_PUBLIC_CTF_ADDRESS=", address(ctf));
        console2.log("NEXT_PUBLIC_FACTORY_ADDRESS=", address(factory));
        console2.log("NEXT_PUBLIC_LENDING_POOL_ADDRESS=", address(lendingPool));
        console2.log("NEXT_PUBLIC_COLLATERAL_MANAGER_ADDRESS=", address(collateralManager));
        console2.log("NEXT_PUBLIC_LIQUIDATION_ENGINE_ADDRESS=", address(liquidationEngine));
        console2.log("NEXT_PUBLIC_PRICE_ORACLE_ADDRESS=", address(priceOracle));
        console2.log("NEXT_PUBLIC_ROUTER_ADDRESS=", address(router));
        console2.log("NEXT_PUBLIC_VAULT_YES_ADDRESS=", vaultYes);
        console2.log("NEXT_PUBLIC_VAULT_NO_ADDRESS=", vaultNo);
        console2.log("-------------------------------------------");
        console2.log("");
        console2.log("To verify contracts on Polygonscan:");
        console2.log("forge verify-contract <ADDRESS> <CONTRACT> --chain amoy");
        console2.log("=============================================");
    }
}

/*//////////////////////////////////////////////////////////////
                    CREATE ADDITIONAL VAULTS
//////////////////////////////////////////////////////////////*/

/// @title CreateVault
/// @notice Script to create new vaults on existing deployment
contract CreateVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load from env
        address factoryAddr = vm.envAddress("FACTORY_ADDRESS");
        address oracleAddr = vm.envAddress("ORACLE_ADDRESS");
        address cmAddr = vm.envAddress("COLLATERAL_MANAGER_ADDRESS");

        uint256 positionId = vm.envUint("POSITION_ID");
        string memory name = vm.envString("VAULT_NAME");
        string memory symbol = vm.envString("VAULT_SYMBOL");
        uint256 price = vm.envUint("VAULT_PRICE"); // 8 decimals

        PositionVaultFactory factory = PositionVaultFactory(factoryAddr);
        PriceOracle oracle = PriceOracle(oracleAddr);
        CollateralManager cm = CollateralManager(cmAddr);

        vm.startBroadcast(deployerPrivateKey);

        address vault = factory.createVault(positionId, name, symbol);
        oracle.setPrice(vault, price);
        cm.setCollateralConfig(vault, 6000, 7500, 500); // 60% LTV, 75% threshold, 5% bonus

        vm.stopBroadcast();

        console2.log("Created vault:", vault);
        console2.log("  Position ID:", positionId);
        console2.log("  Name:", name);
        console2.log("  Symbol:", symbol);
        console2.log("  Price:", price);
    }
}

/*//////////////////////////////////////////////////////////////
                    MINT TEST TOKENS
//////////////////////////////////////////////////////////////*/

/// @title MintTokens
/// @notice Mint test tokens to an address
contract MintTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address usdcAddr = vm.envAddress("USDC_ADDRESS");
        address ctfAddr = vm.envAddress("CTF_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT");

        MockUSDC usdc = MockUSDC(usdcAddr);
        MockCTF ctf = MockCTF(ctfAddr);

        vm.startBroadcast(deployerPrivateKey);

        usdc.mint(recipient, 100_000e6);     // 100k USDC
        ctf.mint(recipient, 1, 1_000e18);    // 1k YES tokens
        ctf.mint(recipient, 2, 1_000e18);    // 1k NO tokens

        vm.stopBroadcast();

        console2.log("Minted to", recipient);
        console2.log("  100,000 USDC");
        console2.log("  1,000 YES tokens (ID: 1)");
        console2.log("  1,000 NO tokens (ID: 2)");
    }
}
