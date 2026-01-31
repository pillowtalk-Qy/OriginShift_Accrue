# Accrue - Polymarket 流动性协议

![Accrue Banner](https://img.shields.io/badge/Accrue-Polymarket%20Liquidity-3ecf8e?style=for-the-badge)
![Network](https://img.shields.io/badge/Network-Polygon%20Amoy-8247e5?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Testnet%20Live-success?style=for-the-badge)

## 🎯 项目简介

**Accrue** 是一个创新的 DeFi 协议，专为 Polymarket 预测市场用户设计。通过 Accrue，用户可以：

- 🔒 **锁定仓位**：存入 Polymarket 的 CTF (Conditional Token Framework) 代币
- 💰 **释放流动性**：以锁定的仓位为抵押借入 USDC
- 📈 **赚取收益**：让协议自动管理资金，获取被动收益

### 核心特性

- ✅ 无需出售预测市场仓位即可获得流动性
- ✅ 灵活的借贷选项（自主管理 / 协议托管）
- ✅ 实时健康因子监控，避免清算风险
- ✅ 自动化收益策略，最大化资金效率
- ✅ 完全去中心化，用户保持仓位所有权

## 🏗️ 技术架构

### 智能合约（后端）

- **PositionVault**: ERC4626 标准金库，管理 CTF 代币
- **LendingPool**: 借贷池，提供 USDC 流动性
- **CollateralManager**: 抵押品管理，计算健康因子
- **PriceOracle**: 价格预言机，提供实时价格数据
- **LiquidationEngine**: 清算引擎，保护协议安全

### 前端（DApp）

- **纯 HTML + CSS + JavaScript**：无需构建工具，即开即用
- **Ethers.js v5**：与区块链交互
- **响应式设计**：支持桌面和移动端
- **实时数据更新**：链上数据实时同步

## 📦 部署合约地址（Polygon Amoy 测试网）

```javascript
const CONTRACTS = {
  // 核心合约
  PositionVaultFactory: "0x300B07ADbb3F5A6a842CE3D18F74823682F0c214",
  LendingPool: "0x6965c3E71369f486254aDBe93Fc1D40231F51Fb9",
  CollateralManager: "0xCF00F48F2cfC4e1A5E61723B46D47223a01479fd",
  PriceOracle: "0x713C7D391d24323509c258BeFE95d6B08C0f8274",
  
  // 测试代币
  USDC: "0xDF3B67F50e92852168Fb5cD6048D76cF3447D8a0",
  CTF: "0x7E620820562bcA813cbBf4AAc171989b8abdFc2b",
  
  // 示例金库
  VaultYES: "0x52326aC01109DcdBcb013c960b3BBB14e3946c17",
  VaultNO: "0x50A5aAf2706406E0A318F943D7A14cFF49265f03",
};
```

**网络信息**：
- **Chain ID**: 80002
- **RPC**: https://rpc-amoy.polygon.technology
- **浏览器**: https://amoy.polygonscan.com

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/your-username/accrue-dapp.git
cd accrue-dapp
```

### 2. 本地运行

由于项目使用纯 HTML/CSS/JS，可以直接在浏览器打开：

```bash
# 使用 Python 启动简单 HTTP 服务器
python -m http.server 8000

# 或使用 Node.js http-server
npx http-server -p 8000
```

然后访问 `http://localhost:8000`

### 3. 配置 MetaMask

1. 安装 [MetaMask](https://metamask.io/) 浏览器插件
2. 添加 Polygon Amoy 测试网：
   - **网络名称**: Polygon Amoy Testnet
   - **RPC URL**: https://rpc-amoy.polygon.technology
   - **Chain ID**: 80002
   - **货币符号**: MATIC
   - **区块浏览器**: https://amoy.polygonscan.com

3. 获取测试 MATIC：
   - 访问 [Polygon Faucet](https://faucet.polygon.technology/)
   - 选择 Amoy 测试网
   - 输入钱包地址领取测试币

### 4. 获取测试代币

联系项目团队获取测试 USDC 和 CTF 代币，或在合约中调用 `mint` 函数（如果有权限）。

## 📖 使用指南

### 步骤 1: 锁定仓位

1. 连接 MetaMask 钱包
2. 选择金库（BTC $100k 看涨/看跌）
3. 输入要锁定的 CTF 代币数量
4. 点击"授权代币"
5. 点击"锁定仓位"

### 步骤 2: 释放流动性

选择管理方式：

#### 方式 A: 自主管理
- 自己控制借入的 USDC
- 手动管理健康因子
- 需要自行还款

#### 方式 B: 协议托管（推荐）
- 协议自动借款并部署到 DeFi 策略
- 自动维护健康因子
- 赚取被动收益（预期 APY 12.5%）

### 步骤 3: 收益管理

- 实时查看健康因子
- 监控累计收益
- 随时偿还债务或终止仓位

## 🧪 测试清单

在测试网上验证以下功能：

- [ ] 连接 MetaMask 钱包
- [ ] 查看 CTF 代币余额
- [ ] 授权 CTF 代币给 Vault
- [ ] 存入 CTF 到 Vault
- [ ] 存入 Vault 份额作为抵押品
- [ ] 查看健康因子和最大借款额
- [ ] 借入 USDC（自主管理）
- [ ] 启用协议托管
- [ ] 查看累计收益实时增长
- [ ] 偿还部分债务
- [ ] 偿还全部债务
- [ ] 取回抵押品
- [ ] 从 Vault 取回 CTF
- [ ] 在区块链浏览器查看所有交易

## 📁 项目结构

```
accrue-dapp/
├── index.html          # 主页面（UI）
├── app.js             # 应用逻辑（Web3 交互）
├── README.md          # 项目文档
├── LICENSE            # 开源许可
└── assets/            # 资源文件
    ├── logo.png
    └── screenshots/
```

## 🔧 技术栈

- **前端**: HTML5, CSS3, JavaScript (ES6+)
- **区块链**: Ethers.js v5
- **网络**: Polygon Amoy Testnet
- **标准**: ERC20, ERC1155, ERC4626
- **字体**: Orbitron, IBM Plex Mono

## 🎨 设计特色

- **赛博朋克风格**：深色主题 + 霓虹绿色调
- **动画效果**：流畅的页面切换和状态反馈
- **实时数据**：收益和健康因子实时更新
- **响应式布局**：完美适配各种屏幕尺寸

## 🔐 安全特性

- ✅ 健康因子实时监控
- ✅ 清算保护机制
- ✅ 链上数据验证
- ✅ 交易前置检查
- ✅ 错误处理和用户提示

## 🛣️ 路线图

### Phase 1: 测试网上线 ✅
- [x] 核心合约部署
- [x] 前端 DApp 开发
- [x] 测试网功能验证

### Phase 2: 主网准备
- [ ] 安全审计
- [ ] Gas 优化
- [ ] 用户反馈收集

### Phase 3: 主网部署
- [ ] Polygon 主网部署
- [ ] 集成真实 Polymarket 数据
- [ ] 社区治理启动

### Phase 4: 生态扩展
- [ ] 支持更多预测市场
- [ ] 多链部署
- [ ] 收益策略多样化

## 🤝 贡献指南

我们欢迎社区贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📝 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 👥 团队

- **合约开发**: [Max]
- **前端开发**: [Qy]
- **产品设计**: [Qy、Max、Chris]
- **产品运营**: [Damia]

## 📞 联系方式

- **项目官网**: [https://accrue.xyz](https://accrue.xyz)
- **Twitter**: [@AccrueProtocol](https://twitter.com/AccrueProtocol)
- **Discord**: [Join our community](https://discord.gg/accrue)
- **Email**: team@accrue.xyz

## 🙏 致谢

感谢以下项目的启发和支持：

- [Polymarket](https://polymarket.com/) - 预测市场平台
- [Aave](https://aave.com/) - 借贷协议参考
- [ERC4626](https://eips.ethereum.org/EIPS/eip-4626) - 金库标准

## ⚠️ 免责声明

本项目目前处于测试阶段，仅供学习和研究使用。请勿在主网使用测试版本。使用本协议时请自行承担风险。

---

**Built with ❤️ for the DeFi community**

如有任何问题，请提交 [Issue](https://github.com/your-username/accrue-dapp/issues) 或联系团队。
