# Accrue DApp - 部署和测试指南

## 📋 目录

1. [环境准备](#环境准备)
2. [部署步骤](#部署步骤)
3. [测试流程](#测试流程)
4. [常见问题](#常见问题)
5. [调试技巧](#调试技巧)

---

## 环境准备

### 1. 安装必要工具

#### MetaMask 钱包
1. 访问 https://metamask.io/
2. 下载并安装浏览器插件
3. 创建新钱包或导入现有钱包

#### 配置 Polygon Amoy 测试网

在 MetaMask 中添加网络：

```
网络名称: Polygon Amoy Testnet
RPC URL: https://rpc-amoy.polygon.technology
Chain ID: 80002
货币符号: MATIC
区块浏览器: https://amoy.polygonscan.com
```

或者点击钱包连接时，DApp 会自动提示添加网络。

### 2. 获取测试代币

#### 获取测试 MATIC

1. 访问 Polygon Faucet: https://faucet.polygon.technology/
2. 选择 "Polygon Amoy"
3. 输入您的钱包地址
4. 完成验证并领取（每天可领取一次）

#### 获取测试 USDC 和 CTF

**方法 1: 联系团队**
- 发送邮件到 team@accrue.xyz，提供您的钱包地址
- 或在 Discord 频道请求

**方法 2: 调用合约 mint 函数（如果有权限）**

```javascript
// 在浏览器控制台执行
const mockUSDC = new ethers.Contract(
  "0xDF3B67F50e92852168Fb5cD6048D76cF3447D8a0",
  ["function mint(address to, uint256 amount) external"],
  signer
);

// Mint 10,000 USDC (6 decimals)
await mockUSDC.mint(yourAddress, ethers.utils.parseUnits("10000", 6));

// Mint CTF tokens
const mockCTF = new ethers.Contract(
  "0x7E620820562bcA813cbBf4AAc171989b8abdFc2b",
  ["function mint(address to, uint256 id, uint256 amount) external"],
  signer
);

// Mint 1000 YES tokens (Position ID: 1)
await mockCTF.mint(yourAddress, 1, ethers.utils.parseUnits("1000", 18));

// Mint 1000 NO tokens (Position ID: 2)
await mockCTF.mint(yourAddress, 2, ethers.utils.parseUnits("1000", 18));
```

---

## 部署步骤

### 本地部署

#### 方法 1: 使用 Python

```bash
# 克隆项目
git clone https://github.com/your-username/accrue-dapp.git
cd accrue-dapp

# 启动本地服务器
python -m http.server 8000

# 访问 http://localhost:8000
```

#### 方法 2: 使用 Node.js

```bash
# 安装 http-server（如果还没安装）
npm install -g http-server

# 启动服务器
http-server -p 8000

# 访问 http://localhost:8000
```

#### 方法 3: 使用 VS Code Live Server

1. 安装 "Live Server" 插件
2. 右键点击 `index.html`
3. 选择 "Open with Live Server"

### 云端部署

#### 部署到 GitHub Pages

```bash
# 1. 创建新仓库
# 2. 推送代码
git add .
git commit -m "Initial commit"
git push origin main

# 3. 在仓库设置中启用 GitHub Pages
# Settings > Pages > Source: main branch > Save
```

访问地址：`https://your-username.github.io/accrue-dapp/`

#### 部署到 Vercel

```bash
# 1. 安装 Vercel CLI
npm install -g vercel

# 2. 部署
vercel

# 3. 按提示完成配置
```

#### 部署到 Netlify

1. 将代码推送到 GitHub
2. 访问 https://netlify.com
3. 点击 "New site from Git"
4. 选择您的仓库
5. 点击 "Deploy site"

---

## 测试流程

### 完整功能测试

#### 测试 1: 钱包连接

```
✓ 点击"连接钱包"按钮
✓ MetaMask 弹出授权请求
✓ 确认连接
✓ 页面显示钱包地址（0x1234...5678）
✓ 网络显示"Polygon Amoy 测试网"
```

#### 测试 2: 查看余额

```
✓ 连接后自动加载链上数据
✓ "您的余额"显示 CTF 代币数量
✓ "当前价格"显示实时价格
✓ "总锁仓量"显示金库 TVL
✓ 控制台输出加载日志
```

#### 测试 3: 锁定仓位

```
✓ 选择金库（YES 或 NO）
✓ 输入锁仓数量（或点击"最大"）
✓ 点击"授权代币"
✓ MetaMask 确认授权交易
✓ 等待交易确认
✓ 显示"代币授权成功"提示
✓ "锁定仓位"按钮变为可用
✓ 点击"锁定仓位"
✓ MetaMask 确认 3 笔交易：
  - 存入 Vault
  - 授权 Vault 份额
  - 存入抵押品
✓ 显示"仓位锁定成功"提示
✓ 自动跳转到"释放流动性"页面
```

#### 测试 4: 借款（自主管理）

```
✓ 选择"自主管理"选项卡
✓ 输入借款金额（或点击"最大"）
✓ 点击"借入 USDC"
✓ MetaMask 确认借款交易
✓ 显示"USDC 借入成功"提示
✓ 自动跳转到"收益管理"页面
✓ 查看累计收益开始增长
```

#### 测试 5: 协议托管

```
✓ 返回"释放流动性"页面
✓ 选择"协议托管"选项卡
✓ 点击"启用自动策略"
✓ MetaMask 确认交易
✓ 协议自动借款（80% 最大额度）
✓ 显示"协议托管已启用"提示
✓ 跳转到"收益管理"页面
✓ 收益实时增长
```

#### 测试 6: 健康因子监控

```
✓ 查看健康因子数值
✓ 健康因子 > 1.5: 绿色，显示"安全"
✓ 健康因子 1.2-1.5: 黄色，显示"警告"
✓ 健康因子 < 1.2: 红色，显示"危险"
✓ 健康因子条自动更新
```

#### 测试 7: 偿还债务

```
✓ 点击"偿还债务"按钮
✓ 输入偿还金额
✓ 点击"确认偿还"
✓ MetaMask 确认 2 笔交易：
  - 授权 USDC
  - 偿还债务
✓ 债务减少
✓ 健康因子上升
```

#### 测试 8: 终止仓位

```
✓ 点击"终止仓位"按钮
✓ 查看终止摘要
✓ 点击"确认终止"
✓ MetaMask 确认多笔交易：
  - 授权 USDC（如有债务）
  - 偿还债务（如有）
  - 取回抵押品
  - 从 Vault 取回 CTF
✓ 显示"仓位终止成功"
✓ 返回"锁定仓位"页面
✓ 余额恢复
```

### 区块链浏览器验证

每笔交易后，检查以下内容：

```
1. 打开 https://amoy.polygonscan.com
2. 输入您的钱包地址
3. 查看交易列表
4. 点击交易哈希查看详情：
   ✓ 状态: Success
   ✓ Block: 确认块数
   ✓ From: 您的地址
   ✓ To: 合约地址
   ✓ Value: 0 MATIC（或实际值）
   ✓ Gas Used: 实际消耗
```

---

## 常见问题

### Q1: 连接钱包后没有反应

**解决方案**：
```
1. 检查 MetaMask 是否已解锁
2. 确认网络是 Polygon Amoy (Chain ID: 80002)
3. 刷新页面重试
4. 打开浏览器控制台查看错误信息
```

### Q2: 交易失败 "insufficient funds"

**解决方案**：
```
1. 确认有足够的 MATIC 用于 gas 费用
2. 访问 Faucet 领取测试 MATIC
3. 降低交易金额重试
```

### Q3: 授权失败

**解决方案**：
```
1. 检查代币余额是否充足
2. 确认选择了正确的金库
3. 清除之前的授权重新授权：
   await ctf.setApprovalForAll(vaultAddress, false);
   await ctf.setApprovalForAll(vaultAddress, true);
```

### Q4: 健康因子显示 "NaN"

**解决方案**：
```
1. 确认已成功借款
2. 刷新页面重新加载数据
3. 检查控制台是否有错误
```

### Q5: 收益不增长

**解决方案**：
```
1. 确认已成功借款
2. 检查是否选择了协议托管
3. 等待至少 10 秒观察变化
4. 刷新页面重新加载
```

### Q6: 无法取回抵押品

**解决方案**：
```
1. 确认所有债务已偿还
2. 检查健康因子是否 > 1
3. 确认有足够的 MATIC 用于 gas
4. 尝试先偿还债务再取回
```

---

## 调试技巧

### 浏览器控制台

打开开发者工具（F12），查看控制台输出：

```javascript
// 正常日志示例
✅ Web3 初始化成功
📊 开始加载链上数据...
💰 CTF 余额: 1000.00
💵 当前价格: 0.60
🔒 用户抵押品: 100.00
💳 用户债务: 36.00
❤️ 健康因子: 1.67
✅ 链上数据加载完成
```

### 查看合约调用

```javascript
// 在控制台执行
console.log('Contracts:', contracts);
console.log('State:', state);

// 手动调用合约
const balance = await contracts.ctf.balanceOf(state.address, 1);
console.log('Balance:', ethers.utils.formatUnits(balance, 18));
```

### 模拟交易

```javascript
// 估算 gas
const gasEstimate = await contracts.lendingPool.estimateGas.borrow(
  ethers.utils.parseUnits("100", 6)
);
console.log('Gas estimate:', gasEstimate.toString());
```

### 网络请求监控

1. 打开开发者工具 > Network 标签
2. 筛选 "Fetch/XHR"
3. 查看 RPC 请求和响应
4. 检查是否有失败的请求

### 事件监听

```javascript
// 监听存款事件
contracts.vaultYES.on("Deposit", (sender, owner, assets, shares, event) => {
  console.log('存款事件:', {
    sender,
    owner,
    assets: ethers.utils.formatUnits(assets, 18),
    shares: ethers.utils.formatUnits(shares, 18),
    txHash: event.transactionHash
  });
});
```

---

## 性能优化建议

### 1. 减少链上调用

```javascript
// ❌ 不好：多次单独调用
const balance1 = await ctf.balanceOf(address, 1);
const balance2 = await ctf.balanceOf(address, 2);
const price = await oracle.getPrice(vault);

// ✅ 更好：批量调用
const [balance1, balance2, price] = await Promise.all([
  ctf.balanceOf(address, 1),
  ctf.balanceOf(address, 2),
  oracle.getPrice(vault)
]);
```

### 2. 缓存数据

```javascript
// 缓存不常变化的数据
let cachedPrice = null;
let lastPriceUpdate = 0;

async function getPrice() {
  const now = Date.now();
  if (cachedPrice && now - lastPriceUpdate < 60000) {
    return cachedPrice;
  }
  
  cachedPrice = await oracle.getPrice(vault);
  lastPriceUpdate = now;
  return cachedPrice;
}
```

### 3. 错误重试

```javascript
async function retryOperation(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(r => setTimeout(r, 1000 * (i + 1)));
    }
  }
}
```

---

## 安全检查清单

部署前确认：

- [ ] 所有合约地址正确
- [ ] RPC 端点可访问
- [ ] 测试代币可获取
- [ ] 所有功能测试通过
- [ ] 错误处理完善
- [ ] 用户提示清晰
- [ ] 交易哈希可查询
- [ ] 健康因子计算准确
- [ ] 收益计算正确
- [ ] 终止流程完整

---

## 支持

遇到问题？

1. 查看 [README.md](README.md)
2. 搜索 [GitHub Issues](https://github.com/your-username/accrue-dapp/issues)
3. 加入 [Discord](https://discord.gg/accrue) 社区
4. 发送邮件到 team@accrue.xyz

---

**祝您测试顺利！** 🚀
