# PolyLend 前端对接文档

## 合约地址

### Polygon Amoy 测试网 (Chain ID: 80002)

```typescript
const CONTRACTS_AMOY = {
  // 核心合约
  PositionVaultFactory: "0x300B07ADbb3F5A6a842CE3D18F74823682F0c214",
  LendingPool: "0x6965c3E71369f486254aDBe93Fc1D40231F51Fb9",
  CollateralManager: "0xCF00F48F2cfC4e1A5E61723B46D47223a01479fd",
  LiquidationEngine: "0x7757B661D785a24930E2fFc5Fe4baE8149AAb104",
  PriceOracle: "0x713C7D391d24323509c258BeFE95d6B08C0f8274",
  PolyLendRouter: "0xBea2E5798a2FB1E35ceEf335Fda5CF80D249FF2A",
  
  // Mock 代币 (测试网)
  USDC: "0xDF3B67F50e92852168Fb5cD6048D76cF3447D8a0",
  CTF: "0x7E620820562bcA813cbBf4AAc171989b8abdFc2b",
  
  // 示例 Vault
  VaultYES: "0x52326aC01109DcdBcb013c960b3BBB14e3946c17",  // BTC 100k YES
  VaultNO: "0x50A5aAf2706406E0A318F943D7A14cFF49265f03",   // BTC 100k NO
};
```

### Polygon Mainnet (Chain ID: 137) - 待部署

```typescript
const CONTRACTS_MAINNET = {
  // 核心合约 - 待部署
  PositionVaultFactory: "0x...",
  LendingPool: "0x...",
  CollateralManager: "0x...",
  LiquidationEngine: "0x...",
  PriceOracle: "0x...",
  PolyLendRouter: "0x...",
  
  // 真实代币
  USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
  PolymarketCTF: "0x4D97DCd97eC945f40cF65F87097ACe5EA0476045",
};
```

### 前端 .env 配置 (Amoy 测试网)

```bash
NEXT_PUBLIC_CHAIN_ID=80002
NEXT_PUBLIC_RPC_URL=https://rpc-amoy.polygon.technology

NEXT_PUBLIC_USDC_ADDRESS=0xDF3B67F50e92852168Fb5cD6048D76cF3447D8a0
NEXT_PUBLIC_CTF_ADDRESS=0x7E620820562bcA813cbBf4AAc171989b8abdFc2b
NEXT_PUBLIC_FACTORY_ADDRESS=0x300B07ADbb3F5A6a842CE3D18F74823682F0c214
NEXT_PUBLIC_LENDING_POOL_ADDRESS=0x6965c3E71369f486254aDBe93Fc1D40231F51Fb9
NEXT_PUBLIC_COLLATERAL_MANAGER_ADDRESS=0xCF00F48F2cfC4e1A5E61723B46D47223a01479fd
NEXT_PUBLIC_LIQUIDATION_ENGINE_ADDRESS=0x7757B661D785a24930E2fFc5Fe4baE8149AAb104
NEXT_PUBLIC_PRICE_ORACLE_ADDRESS=0x713C7D391d24323509c258BeFE95d6B08C0f8274
NEXT_PUBLIC_ROUTER_ADDRESS=0xBea2E5798a2FB1E35ceEf335Fda5CF80D249FF2A
NEXT_PUBLIC_VAULT_YES_ADDRESS=0x52326aC01109DcdBcb013c960b3BBB14e3946c17
NEXT_PUBLIC_VAULT_NO_ADDRESS=0x50A5aAf2706406E0A318F943D7A14cFF49265f03
```

---

## 1. 全局数据查询

### 1.1 获取所有 PositionVault

```typescript
// PositionVaultFactory
interface VaultInfo {
  address: string;
  positionId: bigint;
  name: string;
  symbol: string;
  totalAssets: bigint;  // 总锁仓量 (18 decimals)
  price: bigint;        // 价格 (8 decimals)
  ltv: number;          // LTV (basis points, e.g., 6000 = 60%)
  liquidationThreshold: number;
}

// 获取 Vault 数量
const vaultCount = await factory.getVaultCount();

// 获取所有 Vault 地址
const allVaults: string[] = await factory.getAllVaults();

// 通过 positionId 获取 Vault
const vaultAddress = await factory.getVault(positionId);
```

### 1.2 获取单个 Vault 详情

```typescript
// PositionVault 合约
const vault = new Contract(vaultAddress, PositionVaultABI);

const name = await vault.name();           // ERC20 名称
const symbol = await vault.symbol();       // ERC20 符号
const positionId = await vault.positionId(); // Polymarket Position ID
const totalAssets = await vault.totalAssets(); // 总锁仓 CTF 数量 (18 decimals)
const totalSupply = await vault.totalSupply(); // 总发行份额 (与 totalAssets 1:1)
```

### 1.3 获取 Vault 价格和配置

```typescript
// PriceOracle
const [price, lastUpdated, isValid] = await priceOracle.getPriceData(vaultAddress);
// price: 8 decimals (e.g., 60000000 = $0.60)

// CollateralManager
const config = await collateralManager.getCollateralConfig(vaultAddress);
// config.isActive: bool
// config.ltv: uint256 (basis points, 6000 = 60%)
// config.liquidationThreshold: uint256 (basis points, 7500 = 75%)
// config.liquidationBonus: uint256 (basis points, 500 = 5%)
```

---

## 2. 借贷池数据

### 2.1 池子概览

```typescript
// LendingPool
const totalDeposits = await lendingPool.totalDeposits();    // USDC 总存款 (6 decimals)
const totalBorrows = await lendingPool.totalBorrows();      // USDC 总借款 (6 decimals)
const availableLiquidity = await lendingPool.availableLiquidity(); // 可用流动性
const utilizationRate = await lendingPool.getUtilizationRate();    // 利用率 (18 decimals, 1e18 = 100%)

// 当前利率 (per-second rate, 18 decimals)
const [depositRate, borrowRate] = await lendingPool.getCurrentRates();

// 转换为年化利率 (APY)
const SECONDS_PER_YEAR = 31536000n;
const depositAPY = depositRate * SECONDS_PER_YEAR; // 18 decimals
const borrowAPY = borrowRate * SECONDS_PER_YEAR;   // 18 decimals

// 或直接从 InterestRateModel 获取年化利率
const [annualBorrowRate, annualDepositRate] = await interestRateModel.getAnnualRates(utilizationRate);
```

### 2.2 利率模型参数

```typescript
// InterestRateModel
const baseRate = await interestRateModel.baseRate();           // 基础利率 (18 decimals)
const slope1 = await interestRateModel.slope1();               // 斜率1
const slope2 = await interestRateModel.slope2();               // 斜率2
const optimalUtilization = await interestRateModel.optimalUtilization(); // 最优利用率
```

---

## 3. 用户数据查询

### 3.1 存款人（Lender）数据

```typescript
// LendingPool
const shares = await lendingPool.sharesOf(userAddress);     // 用户份额
const balance = await lendingPool.balanceOf(userAddress);   // 用户余额(含利息, 6 decimals)

// 份额转资产
const assets = await lendingPool.convertToAssets(shares);
// 资产转份额
const sharesToMint = await lendingPool.convertToShares(amount);
```

### 3.2 借款人（Borrower）数据

```typescript
// LendingPool
const debt = await lendingPool.debtOf(userAddress);  // 当前债务(含利息, 6 decimals)

// CollateralManager
const healthFactor = await collateralManager.getHealthFactor(userAddress); // 健康因子 (18 decimals)
// healthFactor < 1e18 表示可被清算

const maxBorrow = await collateralManager.getMaxBorrowAmount(userAddress); // 最大可借 (6 decimals)
const totalCollateralValue = await collateralManager.getTotalCollateralValue(userAddress); // 抵押品总值 (8 decimals)
const isLiquidatable = await collateralManager.isLiquidatable(userAddress); // 是否可清算

// 获取用户所有抵押品
const [vaults, amounts] = await collateralManager.getUserCollaterals(userAddress);
// vaults: address[] - 抵押的 Vault 地址列表
// amounts: uint256[] - 对应的抵押数量 (18 decimals)

// 获取单个 Vault 的抵押量
const collateralAmount = await collateralManager.getCollateralAmount(userAddress, vaultAddress);
```

### 3.3 用户 CTF 余额

```typescript
// Polymarket CTF (ERC1155)
const ctfBalance = await ctf.balanceOf(userAddress, positionId);

// PositionVault (ERC20)
const vaultShares = await vault.balanceOf(userAddress);
```

---

## 4. 用户操作

### 4.1 存款人操作

```typescript
// 1. 存入 USDC 提供流动性
await usdc.approve(lendingPool.address, amount);
await lendingPool.deposit(amount); // amount: 6 decimals

// 2. 取回 USDC
await lendingPool.withdraw(shares); // shares: 从 sharesOf() 获取
```

### 4.2 借款人操作

```typescript
// 1. 将 CTF 存入 PositionVault
await ctf.setApprovalForAll(vault.address, true);
await vault.deposit(amount, userAddress); // amount: 18 decimals

// 2. 将 Vault 份额存为抵押品
await vault.approve(collateralManager.address, amount);
await collateralManager.depositCollateral(vault.address, amount);

// 3. 借出 USDC
await lendingPool.borrow(borrowAmount); // borrowAmount: 6 decimals

// 4. 偿还 USDC
await usdc.approve(lendingPool.address, repayAmount);
await lendingPool.repay(repayAmount); // 传 type(uint256).max 全部还清

// 5. 取回抵押品
await collateralManager.withdrawCollateral(vault.address, amount);

// 6. 从 PositionVault 取回 CTF
await vault.withdraw(amount, userAddress);
```

### 4.3 清算操作

```typescript
// 检查是否可清算
const canLiquidate = await liquidationEngine.canLiquidate(borrowerAddress);

// 获取清算信息
const [maxDebtToRepay, collateralToReceive] = await liquidationEngine.getLiquidationInfo(
  borrowerAddress, 
  collateralVaultAddress
);

// 执行清算
await usdc.approve(liquidationEngine.address, debtToRepay);
const collateralSeized = await liquidationEngine.liquidate(
  borrowerAddress,
  collateralVaultAddress,
  debtToRepay
);
```

---

## 5. 数据格式转换

### 5.1 Decimals 说明

| 数据类型 | Decimals | 示例 |
|---------|----------|------|
| USDC | 6 | `1000000` = $1 |
| Position Token (CTF/Vault) | 18 | `1e18` = 1 token |
| 价格 | 8 | `60000000` = $0.60 |
| 利率/利用率/健康因子 | 18 | `0.5e18` = 50% |
| Basis Points | - | `6000` = 60% |

### 5.2 前端格式化示例

```typescript
import { formatUnits, parseUnits } from 'ethers';

// USDC
const usdcDisplay = formatUnits(usdcAmount, 6);      // "1000.00"
const usdcWei = parseUnits("1000", 6);               // 1000000000n

// Position Tokens
const tokenDisplay = formatUnits(tokenAmount, 18);  // "100.0"
const tokenWei = parseUnits("100", 18);             // 100000000000000000000n

// 价格 (8 decimals)
const priceUSD = Number(formatUnits(price, 8));     // 0.60

// 利率转百分比
const apyPercent = Number(formatUnits(annualRate, 16)); // 5.5 (表示5.5%)

// 健康因子
const hf = Number(formatUnits(healthFactor, 18));   // 1.5

// Basis points 转百分比
const ltvPercent = ltv / 100;                        // 60 (表示60%)
```

---

## 6. 事件监听

```typescript
// PositionVaultFactory
factory.on("VaultCreated", (positionId, vault, name, symbol) => {
  console.log(`New vault: ${vault} for position ${positionId}`);
});

// LendingPool
lendingPool.on("Deposit", (lender, amount, shares) => {});
lendingPool.on("Withdraw", (lender, amount, shares) => {});
lendingPool.on("Borrow", (borrower, amount) => {});
lendingPool.on("Repay", (borrower, amount) => {});

// CollateralManager
collateralManager.on("CollateralDeposited", (user, vault, amount) => {});
collateralManager.on("CollateralWithdrawn", (user, vault, amount) => {});
collateralManager.on("CollateralSeized", (user, vault, amount) => {});

// LiquidationEngine
liquidationEngine.on("Liquidation", (liquidator, borrower, vault, debtRepaid, collateralSeized) => {});

// PriceOracle
priceOracle.on("PriceUpdated", (vault, oldPrice, newPrice, timestamp) => {});
```

---

## 7. 完整数据聚合示例

```typescript
async function getProtocolStats() {
  const [totalDeposits, totalBorrows, utilization] = await Promise.all([
    lendingPool.totalDeposits(),
    lendingPool.totalBorrows(),
    lendingPool.getUtilizationRate()
  ]);
  
  const [annualBorrowRate, annualDepositRate] = await interestRateModel.getAnnualRates(utilization);
  
  return {
    tvl: formatUnits(totalDeposits, 6),
    totalBorrowed: formatUnits(totalBorrows, 6),
    utilization: (Number(utilization) / 1e18 * 100).toFixed(2) + '%',
    depositAPY: (Number(annualDepositRate) / 1e16).toFixed(2) + '%',
    borrowAPY: (Number(annualBorrowRate) / 1e16).toFixed(2) + '%'
  };
}

async function getAllVaultsWithDetails() {
  const vaults = await factory.getAllVaults();
  
  return Promise.all(vaults.map(async (addr) => {
    const vault = new Contract(addr, PositionVaultABI, provider);
    const [name, symbol, positionId, totalAssets] = await Promise.all([
      vault.name(),
      vault.symbol(),
      vault.positionId(),
      vault.totalAssets()
    ]);
    
    const [price, lastUpdated, isValid] = await priceOracle.getPriceData(addr);
    const config = await collateralManager.getCollateralConfig(addr);
    
    return {
      address: addr,
      name,
      symbol,
      positionId: positionId.toString(),
      totalAssets: formatUnits(totalAssets, 18),
      price: formatUnits(price, 8),
      priceValid: isValid,
      ltv: Number(config.ltv) / 100,
      liquidationThreshold: Number(config.liquidationThreshold) / 100
    };
  }));
}

async function getUserPosition(userAddress: string) {
  const [debt, healthFactor, maxBorrow, collaterals] = await Promise.all([
    lendingPool.debtOf(userAddress),
    collateralManager.getHealthFactor(userAddress),
    collateralManager.getMaxBorrowAmount(userAddress),
    collateralManager.getUserCollaterals(userAddress)
  ]);
  
  const [vaults, amounts] = collaterals;
  
  return {
    debt: formatUnits(debt, 6),
    healthFactor: debt > 0 ? (Number(healthFactor) / 1e18).toFixed(2) : '∞',
    maxBorrow: formatUnits(maxBorrow, 6),
    availableToBorrow: formatUnits(maxBorrow - debt, 6),
    collaterals: vaults.map((v, i) => ({
      vault: v,
      amount: formatUnits(amounts[i], 18)
    }))
  };
}
```

---

## 8. ABI 文件

完整 ABI 在编译后位于：

```
out/PositionVaultFactory.sol/PositionVaultFactory.json
out/PositionVault.sol/PositionVault.json
out/LendingPool.sol/LendingPool.json
out/CollateralManager.sol/CollateralManager.json
out/LiquidationEngine.sol/LiquidationEngine.json
out/PriceOracle.sol/PriceOracle.json
out/InterestRateModel.sol/InterestRateModel.json
out/PolyLendRouter.sol/PolyLendRouter.json
```

提取 ABI：
```bash
cat out/LendingPool.sol/LendingPool.json | jq '.abi' > abi/LendingPool.json
```

---

## 9. 测试网使用指南

### 9.1 获取测试代币

在 Amoy 测试网上，Mock USDC 和 CTF 合约有公开的 `mint` 函数：

```typescript
// Mint USDC (需要 deployer 权限，或联系部署者)
await mockUSDC.mint(userAddress, parseUnits("10000", 6)); // 10,000 USDC

// Mint CTF tokens
await mockCTF.mint(userAddress, 1, parseUnits("1000", 18)); // 1,000 YES tokens
await mockCTF.mint(userAddress, 2, parseUnits("1000", 18)); // 1,000 NO tokens
```

### 9.2 测试网区块浏览器

- **Amoy Polygonscan**: https://amoy.polygonscan.com/
- **查看合约**: `https://amoy.polygonscan.com/address/<CONTRACT_ADDRESS>`

### 9.3 RPC 端点

```typescript
const RPC_URLS = {
  amoy: [
    "https://rpc-amoy.polygon.technology",
    "https://polygon-amoy.g.alchemy.com/v2/YOUR_API_KEY",
    "https://polygon-amoy.infura.io/v3/YOUR_API_KEY"
  ],
  mainnet: [
    "https://polygon-rpc.com",
    "https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
  ]
};
```

### 9.4 已验证的操作流程

以下操作已在 Amoy 测试网验证通过：

1. **流动性提供** (Lender)
   - `USDC.approve(LendingPool, amount)` ✓
   - `LendingPool.deposit(amount)` ✓
   - `LendingPool.withdraw(shares)` ✓

2. **抵押借款** (Borrower)
   - `CTF.setApprovalForAll(Vault, true)` ✓
   - `Vault.deposit(amount, receiver)` ✓
   - `Vault.approve(CollateralManager, amount)` ✓
   - `CollateralManager.depositCollateral(vault, amount)` ✓
   - `LendingPool.borrow(amount)` ✓
   - `USDC.approve(LendingPool, amount)` ✓
   - `LendingPool.repay(amount)` ✓
   - `CollateralManager.withdrawCollateral(vault, amount)` ✓
   - `Vault.withdraw(amount, receiver, owner)` ✓
