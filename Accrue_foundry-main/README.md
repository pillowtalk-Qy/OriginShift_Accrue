# PolyLend Protocol

> 基于 Polymarket Position 的借贷协议 - 将预测市场头寸作为抵押品释放流动性

## 目录

- [项目概述](#项目概述)
- [依赖库](#依赖库)
- [系统架构](#系统架构)
- [合约模块](#合约模块)
  - [Module 1: Interfaces (自定义)](#module-1-interfaces-自定义)
  - [Module 2: Libraries](#module-2-libraries)
  - [Module 3: Oracle](#module-3-oracle)
  - [Module 4: Core](#module-4-core)
  - [Module 5: Euler Integration](#module-5-euler-integration)
- [开发路线图](#开发路线图)
- [安全考虑](#安全考虑)

---

## 项目概述

### 背景

用户在 Polymarket 持有的预测市场头寸（Conditional Tokens）在市场结算前无法进一步利用其价值。PolyLend 协议允许用户将这些头寸作为抵押品借出稳定币，释放资金流动性。

### 核心功能

1. **Position 包装**: 将 Polymarket CTF (ERC1155) 包装成 ERC6909
2. **流动性门槛**: 仅允许高流动性市场的头寸作为抵押品
3. **借贷集成**: 与 Euler Protocol 集成实现借贷功能
4. **清算机制**: 处理头寸价值下跌或市场结算的清算场景

### 技术栈

- Solidity ^0.8.24
- Foundry (开发框架)
- OpenZeppelin Contracts 5.x (ERC6909, 访问控制, 安全工具)
- Gnosis Conditional Tokens (Polymarket CTF 基础)
- Euler Vault Kit (借贷基础设施)

```js
# 合约地址
export RPC_URL="https://polygon-amoy.g.alchemy.com/v2/<API_KEY>"
export USDC="0xDF3B67F50e92852168Fb5cD6048D76cF3447D8a0"
export CTF="0x7E620820562bcA813cbBf4AAc171989b8abdFc2b"
export FACTORY="0x300B07ADbb3F5A6a842CE3D18F74823682F0c214"
export LENDING_POOL="0x6965c3E71369f486254aDBe93Fc1D40231F51Fb9"
export COLLATERAL_MANAGER="0xCF00F48F2cfC4e1A5E61723B46D47223a01479fd"
export LIQUIDATION_ENGINE="0x7757B661D785a24930E2fFc5Fe4baE8149AAb104"
export PRICE_ORACLE="0x713C7D391d24323509c258BeFE95d6B08C0f8274"
export ROUTER="0xBea2E5798a2FB1E35ceEf335Fda5CF80D249FF2A"
export VAULT_YES="0x52326aC01109DcdBcb013c960b3BBB14e3946c17"
export VAULT_NO="0x50A5aAf2706406E0A318F943D7A14cFF49265f03"
```

1. 获取 Mock Tokens

```js
# Mint USDC (100,000 USDC = 100000e6)
cast send $USDC "mint(address,uint256)" <YOUR_ADDRESS> 100000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# Mint CTF Position ID 1 (YES tokens, 1000e18)
cast send $CTF "mint(address,uint256,uint256)" <YOUR_ADDRESS> 1 1000000000000000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# Mint CTF Position ID 2 (NO tokens, 1000e18)
cast send $CTF "mint(address,uint256,uint256)" <YOUR_ADDRESS> 2 1000000000000000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>
```

2. 存款人流程 - Add/Remove 流动性

```js
# === 2a. Approve USDC to LendingPool ===
cast send $USDC "approve(address,uint256)" $LENDING_POOL 10000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# === 2b. Deposit 10,000 USDC to LendingPool ===
cast send $LENDING_POOL "deposit(uint256)" 10000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# === 2c. 查看 shares 余额 ===
cast call $LENDING_POOL "sharesOf(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# === 2d. Withdraw (用 shares 数量) ===
cast send $LENDING_POOL "withdraw(uint256)" <SHARES_AMOUNT> \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>
```

3. 借款人流程 - 质押 Position

```js
# 设置 CTF approval for all (ERC1155)
cast send $CTF "setApprovalForAll(address,bool)" $VAULT_YES true \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# 存入 100e18 CTF tokens，获得 pTokens
cast send $VAULT_YES "deposit(uint256,address)" 100000000000000000000 <YOUR_ADDRESS> \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

cast send $VAULT_YES "approve(address,uint256)" $COLLATERAL_MANAGER 100000000000000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

cast send $COLLATERAL_MANAGER "depositCollateral(address,uint256)" $VAULT_YES 100000000000000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

```

4. 借贷

```js
# === 4a. 查看最大可借金额 ===
cast call $COLLATERAL_MANAGER "getMaxBorrowAmount(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# === 4b. 借出 USDC (例如 30 USDC = 30e6) ===
cast send $LENDING_POOL "borrow(uint256)" 30000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# === 4c. 查看债务 ===
cast call $LENDING_POOL "debtOf(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL
```

5. 还款

```js
# === 5a. Approve USDC to LendingPool ===
cast send $USDC "approve(address,uint256)" $LENDING_POOL 40000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# === 5b. 还款 (全额还款用 type(uint256).max) ===
# 部分还款
cast send $LENDING_POOL "repay(uint256)" 30000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# 或全额还款
cast send $LENDING_POOL "repay(uint256)" 115792089237316195423570985008687907853269984665640564039457584007913129639935 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>
```

6. 取回质押品

```js
# === 6a. Withdraw collateral from CollateralManager ===
cast send $COLLATERAL_MANAGER "withdrawCollateral(address,uint256)" $VAULT_YES 100000000000000000000 \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>

# === 6b. Withdraw from PositionVault (取回 CTF) ===
cast send $VAULT_YES "withdraw(uint256,address)" 100000000000000000000 <YOUR_ADDRESS> \
  --rpc-url $RPC_URL --account <YOUR_ACCOUNT>
```

7. 查询状态

```js
# 查看健康因子
cast call $COLLATERAL_MANAGER "getHealthFactor(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# 查看抵押品价值
cast call $COLLATERAL_MANAGER "getTotalCollateralValue(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# 查看是否可被清算
cast call $COLLATERAL_MANAGER "isLiquidatable(address)(bool)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# 查看 USDC 余额
cast call $USDC "balanceOf(address)(uint256)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# 查看池子利用率
cast call $LENDING_POOL "getUtilizationRate()(uint256)" --rpc-url $RPC_URL

# 查看当前利率
cast call $LENDING_POOL "getCurrentRates()(uint256,uint256)" --rpc-url $RPC_URL

# 查看价格
cast call $PRICE_ORACLE "getPrice(address)(uint256)" $VAULT_YES --rpc-url $RPC_URL
```

8. 清算

```js
# 清算人需要先有 USDC
cast send $USDC "approve(address,uint256)" $LIQUIDATION_ENGINE 50000000 \
  --rpc-url $RPC_URL --account <LIQUIDATOR_ACCOUNT>

# 执行清算
cast send $LIQUIDATION_ENGINE "liquidate(address,address,uint256)" \
  <BORROWER_ADDRESS> $VAULT_YES 30000000 \
  --rpc-url $RPC_URL --account <LIQUIDATOR_ACCOUNT>
```

## polygonScan

### Mint

- Mint 100,000 USDC: 0xf4019269e359064cc4022102b67bb5a42fc6e3e06326e8fd05025db17a296619

- Mint 1000 YES tokens where Position ID = 1: 0x2b89a6870f3a4a3474ceeb2b6c80bd7395d3aece31161bdb3fe958dfb95d8b77

- Mint 1000 NO tokens (Position ID 2): 0xd44f55efe7d38b4cf34d729faffc67bbf74459516e05e5bf81a74bd9da8931d3

### Add Liquidity

- Approve USDC: 0xa6cdfcb181ce70a26e783d72a763078edbe693fc1f3ab93fc7ec7bd8310ed61c

- Deposit 10,000 USDC: 0x3e2721f66334ffd17ef7403c4b0865c9d154e041c05026c9c6828fd3f235abe6

- view shares: 0x3e2721f66334ffd17ef7403c4b0865c9d154e041c05026c9c6828fd3f235abe6

### 抵押

- Approve CTF 给 PositionVault: 0x09869485368c1f42f7e84b083252375c64971ff227f2fa63c09ce3a0fba7961f

- Deposit: 0x216ed9f99c9cd11784530b00933bfab91a776bb7088d9d3eff074be4519fb4cf

- Approve pTokens 给 CollateralManager: 0x546e290c33fe6426f3027b0d4e89836ee63a89a09464a4b2b86f65fc1d2a61d9

- Deposit Collateral: 0x711cde48009c222a01547fe97543941855958ee7b0ee34c11bdf44e24638a058

### 借

- 预言机设置价格

  - 0x10d97ff50054d0df724e4d94b4d76df8d64756601c2f5eeef839ede97598ffa3
  - 0xfd89b8b4926a349506b3d063ba20dbc46ed91e96d77e53864846e9436f783156

- 查看最大可借金额: 36000000 [3.6e7]

- 借 30 USDC: 0x8ef9e1e6db43c4bf705eddc880f445aa75baaac4e297a4c8cb3fc39ea3eb6209

- 查看债务: 30000000 [3e7]

### 还款

- 还+fee:
  第一个是只还了 30，第二个是把手续费交了
  - 0x9ac2b83148a6d10a83c3e80c1e383193fc96c3796af2aef77732a748d37cac52
  - 0x6602f21af0280eb81df36e49ff9707f6c207ae295b77b85301ca4870f2f563c1

### 取回抵押品

- 从 CollateralManager 取出:
  - 0x9bae49885faa6ddc9d99dfe40194adeb14eb7f1d86011807d04ad5ae7af26d15
  - 0x7ddfb8a8df6c621a8f7cc92bfb3b51763794e69e3a3cb3b6288059dd3caa4e0f
