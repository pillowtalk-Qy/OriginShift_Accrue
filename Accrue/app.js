// ==================== ABI 定义 ====================
const ABIS = {
    ERC20: [
        "function approve(address spender, uint256 amount) external returns (bool)",
        "function allowance(address owner, address spender) external view returns (uint256)",
        "function balanceOf(address account) external view returns (uint256)",
        "function transfer(address to, uint256 amount) external returns (bool)"
    ],
    
    CTF: [
        "function balanceOf(address account, uint256 id) external view returns (uint256)",
        "function setApprovalForAll(address operator, bool approved) external",
        "function isApprovedForAll(address account, address operator) external view returns (bool)",
        "function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data) external"
    ],
    
    PositionVault: [
        "function name() external view returns (string)",
        "function symbol() external view returns (string)",
        "function positionId() external view returns (uint256)",
        "function totalAssets() external view returns (uint256)",
        "function totalSupply() external view returns (uint256)",
        "function balanceOf(address account) external view returns (uint256)",
        "function deposit(uint256 assets, address receiver) external returns (uint256 shares)",
        "function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares)",
        "function approve(address spender, uint256 amount) external returns (bool)"
    ],
    
    LendingPool: [
        "function totalDeposits() external view returns (uint256)",
        "function totalBorrows() external view returns (uint256)",
        "function availableLiquidity() external view returns (uint256)",
        "function getUtilizationRate() external view returns (uint256)",
        "function getCurrentRates() external view returns (uint256 depositRate, uint256 borrowRate)",
        "function sharesOf(address account) external view returns (uint256)",
        "function balanceOf(address account) external view returns (uint256)",
        "function debtOf(address account) external view returns (uint256)",
        "function deposit(uint256 amount) external returns (uint256 shares)",
        "function withdraw(uint256 shares) external returns (uint256 amount)",
        "function borrow(uint256 amount) external",
        "function repay(uint256 amount) external"
    ],
    
    CollateralManager: [
        "function getHealthFactor(address user) external view returns (uint256)",
        "function getMaxBorrowAmount(address user) external view returns (uint256)",
        "function getTotalCollateralValue(address user) external view returns (uint256)",
        "function isLiquidatable(address user) external view returns (bool)",
        "function getUserCollaterals(address user) external view returns (address[] vaults, uint256[] amounts)",
        "function getCollateralAmount(address user, address vault) external view returns (uint256)",
        "function getCollateralConfig(address vault) external view returns (tuple(bool isActive, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus))",
        "function depositCollateral(address vault, uint256 amount) external",
        "function withdrawCollateral(address vault, uint256 amount) external"
    ],
    
    PriceOracle: [
        "function getPriceData(address vault) external view returns (uint256 price, uint256 lastUpdated, bool isValid)",
        "function getPrice(address vault) external view returns (uint256)"
    ]
};

// ==================== 合约地址 ====================
const CONTRACTS = {
    USDC: "0xDF3B67F50e92852168Fb5cD6048D76cF3447D8a0",
    CTF: "0x7E620820562bcA813cbBf4AAc171989b8abdFc2b",
    PositionVaultFactory: "0x300B07ADbb3F5A6a842CE3D18F74823682F0c214",
    LendingPool: "0x6965c3E71369f486254aDBe93Fc1D40231F51Fb9",
    CollateralManager: "0xCF00F48F2cfC4e1A5E61723B46D47223a01479fd",
    LiquidationEngine: "0x7757B661D785a24930E2fFc5Fe4baE8149AAb104",
    PriceOracle: "0x713C7D391d24323509c258BeFE95d6B08C0f8274",
    VaultYES: "0x52326aC01109DcdBcb013c960b3BBB14e3946c17",
    VaultNO: "0x50A5aAf2706406E0A318F943D7A14cFF49265f03"
};

const POSITION_IDS = {
    YES: 1,
    NO: 2
};

// ==================== 全局状态 ====================
let provider, signer, contracts = {};

const state = {
    connected: false,
    address: '',
    network: 'amoy',
    selectedVault: null,
    selectedVaultAddress: null,
    selectedOption: null,
    balance: 0,
    debt: 0,
    collateral: 0,
    healthFactor: Infinity,
    earnedAmount: 0,
    lastUpdateTime: Date.now(),
    isEarning: false,
    depositTimestamp: null,
    currentPrice: 0
};

let earningsInterval = null;

// ==================== Web3 初始化 ====================
async function initWeb3() {
    if (typeof window.ethereum === 'undefined') {
        throw new Error('请安装 MetaMask 钱包');
    }
    
    provider = new ethers.providers.Web3Provider(window.ethereum);
    signer = provider.getSigner();
    
    // 检查网络
    const network = await provider.getNetwork();
    if (network.chainId !== 80002) {
        // 尝试切换到 Amoy 测试网
        await switchToAmoy();
    }
    
    // 初始化合约实例
    contracts.usdc = new ethers.Contract(CONTRACTS.USDC, ABIS.ERC20, signer);
    contracts.ctf = new ethers.Contract(CONTRACTS.CTF, ABIS.CTF, signer);
    contracts.vaultYES = new ethers.Contract(CONTRACTS.VaultYES, ABIS.PositionVault, signer);
    contracts.vaultNO = new ethers.Contract(CONTRACTS.VaultNO, ABIS.PositionVault, signer);
    contracts.lendingPool = new ethers.Contract(CONTRACTS.LendingPool, ABIS.LendingPool, signer);
    contracts.collateralManager = new ethers.Contract(CONTRACTS.CollateralManager, ABIS.CollateralManager, signer);
    contracts.priceOracle = new ethers.Contract(CONTRACTS.PriceOracle, ABIS.PriceOracle, signer);
    
    console.log('✅ Web3 初始化成功');
    console.log('📝 合约地址:', CONTRACTS);
    
    return true;
}

// ==================== 网络切换 ====================
async function switchToAmoy() {
    try {
        await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: '0x13882' }], // 80002 in hex
        });
    } catch (switchError) {
        // 如果网络不存在，添加网络
        if (switchError.code === 4902) {
            try {
                await window.ethereum.request({
                    method: 'wallet_addEthereumChain',
                    params: [{
                        chainId: '0x13882',
                        chainName: 'Polygon Amoy Testnet',
                        nativeCurrency: {
                            name: 'MATIC',
                            symbol: 'MATIC',
                            decimals: 18
                        },
                        rpcUrls: ['https://rpc-amoy.polygon.technology'],
                        blockExplorerUrls: ['https://amoy.polygonscan.com/']
                    }]
                });
            } catch (addError) {
                throw new Error('添加 Amoy 测试网失败');
            }
        } else {
            throw switchError;
        }
    }
}

// ==================== 从链上加载数据 ====================
async function loadUserDataFromChain() {
    if (!state.connected) return;
    
    try {
        console.log('📊 开始加载链上数据...');
        
        // 1. 获取 CTF 余额
        const balance1 = await contracts.ctf.balanceOf(state.address, POSITION_IDS.YES);
        const balance2 = await contracts.ctf.balanceOf(state.address, POSITION_IDS.NO);
        state.balance = parseFloat(ethers.utils.formatUnits(balance1.add(balance2), 18));
        document.getElementById('userBalance').textContent = formatNumber(state.balance, 2);
        console.log('💰 CTF 余额:', state.balance);
        
        // 2. 获取价格
        const vaultAddress = state.selectedVaultAddress || CONTRACTS.VaultYES;
        const [price, lastUpdated, isValid] = await contracts.priceOracle.getPriceData(vaultAddress);
        state.currentPrice = parseFloat(ethers.utils.formatUnits(price, 8));
        document.getElementById('currentPrice').textContent = '$' + formatNumber(state.currentPrice, 2);
        console.log('💵 当前价格:', state.currentPrice);
        
        // 3. 获取金库总锁仓
        const totalAssets = await contracts.vaultYES.totalAssets();
        document.getElementById('totalLocked').textContent = formatNumber(parseFloat(ethers.utils.formatUnits(totalAssets, 18)), 0);
        
        // 4. 获取 LTV 配置
        const config = await contracts.collateralManager.getCollateralConfig(vaultAddress);
        const ltv = Number(config.ltv) / 100; // basis points to percentage
        document.getElementById('vaultLTV').textContent = ltv + '%';
        
        // 5. 获取用户抵押品
        const userCollateral = await contracts.collateralManager.getCollateralAmount(state.address, vaultAddress);
        state.collateral = parseFloat(ethers.utils.formatUnits(userCollateral, 18));
        console.log('🔒 用户抵押品:', state.collateral);
        
        // 6. 获取用户债务
        const userDebt = await contracts.lendingPool.debtOf(state.address);
        state.debt = parseFloat(ethers.utils.formatUnits(userDebt, 6));
        console.log('💳 用户债务:', state.debt);
        
        // 7. 获取健康因子
        if (state.debt > 0) {
            const hf = await contracts.collateralManager.getHealthFactor(state.address);
            state.healthFactor = parseFloat(ethers.utils.formatUnits(hf, 18));
            console.log('❤️ 健康因子:', state.healthFactor);
            
            state.isEarning = true;
            if (!state.depositTimestamp) {
                state.depositTimestamp = Date.now();
            }
        }
        
        // 8. 获取借款利率
        const [, borrowRate] = await contracts.lendingPool.getCurrentRates();
        const annualBorrowRate = borrowRate.mul(31536000); // seconds per year
        const borrowAPR = parseFloat(ethers.utils.formatUnits(annualBorrowRate, 16)) / 100;
        document.getElementById('borrowAPR').textContent = borrowAPR.toFixed(2) + '%';
        console.log('📈 借款 APR:', borrowAPR);
        
        // 9. 获取可用流动性
        const liquidity = await contracts.lendingPool.availableLiquidity();
        document.getElementById('availableLiquidity').textContent = '$' + formatNumber(parseFloat(ethers.utils.formatUnits(liquidity, 6)), 2);
        
        // 10. 获取最大可借额度
        const maxBorrowAmount = await contracts.collateralManager.getMaxBorrowAmount(state.address);
        const maxBorrowUSD = parseFloat(ethers.utils.formatUnits(maxBorrowAmount, 6));
        document.getElementById('maxBorrow').textContent = '$' + formatNumber(maxBorrowUSD, 2);
        
        updateUI();
        
        // 如果有债务，启动收益计算
        if (state.debt > 0 && state.isEarning) {
            startEarningsCounter();
        }
        
        console.log('✅ 链上数据加载完成');
        
    } catch (error) {
        console.error('❌ 加载链上数据失败:', error);
        handleError(error, '加载数据');
    }
}

// ==================== UI 辅助函数 ====================
function showModal(title, content) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalContent').innerHTML = content;
    document.getElementById('modalOverlay').classList.add('active');
}

function hideModal() {
    document.getElementById('modalOverlay').classList.remove('active');
}

function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.getElementById('toastContainer').appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'toastSlideIn 0.3s reverse';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

function showLoading(message = '正在处理交易...') {
    showModal('交易', `
        <div class="tx-status">
            <div class="tx-spinner"></div>
            <div class="tx-message">${message}</div>
        </div>
    `);
}

function formatNumber(num, decimals = 2) {
    return Number(num).toLocaleString('en-US', {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
    });
}

function handleError(error, operation) {
    console.error(`${operation} 失败:`, error);
    
    let message = error.message || '未知错误';
    
    if (error.code === 4001) {
        message = '用户取消了交易';
    } else if (error.code === -32603) {
        message = '交易执行失败，可能是余额不足或参数错误';
    } else if (message.includes('insufficient funds')) {
        message = 'MATIC 余额不足，无法支付 gas 费用';
    } else if (message.includes('execution reverted')) {
        // 尝试提取 revert 原因
        const match = message.match(/reason="([^"]+)"/);
        if (match) {
            message = `交易失败: ${match[1]}`;
        } else {
            message = '交易被合约拒绝，请检查参数';
        }
    }
    
    showToast(`${operation}失败: ${message}`, 'error');
}

// ==================== 钱包连接 ====================
document.getElementById('connectWalletBtn').addEventListener('click', async () => {
    try {
        showLoading('正在连接钱包...');
        
        await initWeb3();
        
        const accounts = await provider.send("eth_requestAccounts", []);
        state.address = accounts[0];
        state.connected = true;
        
        document.getElementById('connectWalletBtn').classList.add('hidden');
        const walletBtn = document.getElementById('walletAddress');
        walletBtn.textContent = state.address.slice(0, 6) + '...' + state.address.slice(-4);
        walletBtn.classList.remove('hidden');
        
        hideModal();
        showToast('🎉 钱包连接成功');
        
        await loadUserDataFromChain();
        
        // 监听账户切换
        window.ethereum.on('accountsChanged', async (accounts) => {
            if (accounts.length > 0) {
                state.address = accounts[0];
                walletBtn.textContent = state.address.slice(0, 6) + '...' + state.address.slice(-4);
                await loadUserDataFromChain();
                showToast('账户已切换');
            } else {
                location.reload();
            }
        });
        
        // 监听网络切换
        window.ethereum.on('chainChanged', () => {
            location.reload();
        });
        
    } catch (error) {
        hideModal();
        handleError(error, '连接钱包');
    }
});

// ==================== 金库选择 ====================
document.getElementById('vaultSelectBtn').addEventListener('click', () => {
    document.getElementById('vaultOptions').classList.toggle('active');
});

document.querySelectorAll('.select-option').forEach(option => {
    option.addEventListener('click', async () => {
        const vault = option.dataset.vault;
        state.selectedVault = vault;
        state.selectedVaultAddress = vault === 'YES' ? CONTRACTS.VaultYES : CONTRACTS.VaultNO;
        
        document.getElementById('selectedVault').textContent = option.querySelector('strong').textContent;
        document.getElementById('vaultOptions').classList.remove('active');
        
        showToast(`已选择 ${vault} 金库`);
        
        // 刷新价格数据
        if (state.connected) {
            try {
                const [price] = await contracts.priceOracle.getPriceData(state.selectedVaultAddress);
                state.currentPrice = parseFloat(ethers.utils.formatUnits(price, 8));
                document.getElementById('currentPrice').textContent = '$' + formatNumber(state.currentPrice, 2);
            } catch (error) {
                console.error('获取价格失败:', error);
            }
        }
    });
});

document.addEventListener('click', (e) => {
    if (!e.target.closest('.custom-select')) {
        document.getElementById('vaultOptions').classList.remove('active');
    }
});

// ==================== Max 按钮 ====================
document.getElementById('maxLockBtn').addEventListener('click', () => {
    document.getElementById('lockAmount').value = state.balance;
});

document.getElementById('maxBorrowBtn').addEventListener('click', async () => {
    try {
        const maxBorrow = await contracts.collateralManager.getMaxBorrowAmount(state.address);
        const maxBorrowUSD = parseFloat(ethers.utils.formatUnits(maxBorrow, 6));
        // 留一点余量避免精度问题
        document.getElementById('borrowAmount').value = (maxBorrowUSD * 0.99).toFixed(2);
    } catch (error) {
        console.error('获取最大借款失败:', error);
    }
});

// ==================== 授权和存款 ====================
document.getElementById('approveLockBtn').addEventListener('click', async () => {
    if (!state.connected) {
        showToast('请先连接钱包', 'warning');
        return;
    }
    
    if (!state.selectedVaultAddress) {
        showToast('请先选择金库', 'warning');
        return;
    }
    
    try {
        showLoading('正在授权 CTF 代币...');
        
        // 检查是否已授权
        const isApproved = await contracts.ctf.isApprovedForAll(state.address, state.selectedVaultAddress);
        
        if (isApproved) {
            hideModal();
            showToast('代币已授权');
            document.getElementById('depositBtn').disabled = false;
            return;
        }
        
        const tx = await contracts.ctf.setApprovalForAll(state.selectedVaultAddress, true);
        
        console.log('✅ 授权交易已发送:', tx.hash);
        console.log('🔗 查看交易:', `https://amoy.polygonscan.com/tx/${tx.hash}`);
        
        await tx.wait();
        
        hideModal();
        showToast('✅ 代币授权成功');
        
        document.getElementById('depositBtn').disabled = false;
        
    } catch (error) {
        hideModal();
        handleError(error, '授权代币');
    }
});

document.getElementById('depositBtn').addEventListener('click', async () => {
    const amount = document.getElementById('lockAmount').value;
    
    if (!amount || amount <= 0) {
        showToast('请输入有效金额', 'warning');
        return;
    }
    
    if (parseFloat(amount) > state.balance) {
        showToast('余额不足', 'warning');
        return;
    }
    
    try {
        showLoading('步骤 1/3: 将 CTF 存入 Vault...');
        
        const vault = state.selectedVault === 'YES' ? contracts.vaultYES : contracts.vaultNO;
        const amountWei = ethers.utils.parseUnits(amount, 18);
        
        // Step 1: 存入 Vault
        const tx1 = await vault.deposit(amountWei, state.address);
        console.log('✅ Vault 存款交易:', tx1.hash);
        await tx1.wait();
        
        showLoading('步骤 2/3: 授权 Vault 份额...');
        
        // Step 2: 授权 Vault 份额给 CollateralManager
        const tx2 = await vault.approve(CONTRACTS.CollateralManager, amountWei);
        console.log('✅ Vault 授权交易:', tx2.hash);
        await tx2.wait();
        
        showLoading('步骤 3/3: 存入抵押品...');
        
        // Step 3: 存入抵押品
        const tx3 = await contracts.collateralManager.depositCollateral(state.selectedVaultAddress, amountWei);
        console.log('✅ 抵押品存入交易:', tx3.hash);
        console.log('🔗 查看交易:', `https://amoy.polygonscan.com/tx/${tx3.hash}`);
        
        await tx3.wait();
        
        state.collateral = parseFloat(amount);
        state.depositTimestamp = Date.now();
        
        hideModal();
        showToast('🎉 仓位锁定成功！');
        
        await loadUserDataFromChain();
        
        // 自动跳转到下一页
        setTimeout(() => {
            document.querySelector('[data-page="liquidity"]').click();
        }, 1000);
        
    } catch (error) {
        hideModal();
        handleError(error, '存款');
    }
});

// ==================== 流动性选项 ====================
document.querySelectorAll('.option-card').forEach(card => {
    card.addEventListener('click', () => {
        const option = card.dataset.option;
        
        document.querySelectorAll('.option-card').forEach(c => c.classList.remove('selected'));
        card.classList.add('selected');
        
        state.selectedOption = option;
        
        document.getElementById('selfManagedSection').classList.add('hidden');
        document.getElementById('protocolManagedSection').classList.add('hidden');
        
        if (option === 'self') {
            document.getElementById('selfManagedSection').classList.remove('hidden');
        } else {
            document.getElementById('protocolManagedSection').classList.remove('hidden');
        }
    });
});

// ==================== 借款 ====================
document.getElementById('borrowBtn').addEventListener('click', async () => {
    const amount = document.getElementById('borrowAmount').value;
    
    if (!amount || amount <= 0) {
        showToast('请输入有效金额', 'warning');
        return;
    }
    
    try {
        showLoading('正在借入 USDC...');
        
        const amountWei = ethers.utils.parseUnits(amount, 6);
        const tx = await contracts.lendingPool.borrow(amountWei);
        
        console.log('✅ 借款交易已发送:', tx.hash);
        console.log('🔗 查看交易:', `https://amoy.polygonscan.com/tx/${tx.hash}`);
        
        await tx.wait();
        
        state.debt = parseFloat(amount);
        state.isEarning = true;
        state.depositTimestamp = Date.now();
        state.earnedAmount = 0;
        
        hideModal();
        showToast('🎉 USDC 借入成功');
        
        startEarningsCounter();
        await loadUserDataFromChain();
        
        // 跳转到收益管理页面
        setTimeout(() => {
            document.querySelector('[data-page="strategy"]').click();
        }, 1000);
        
    } catch (error) {
        hideModal();
        handleError(error, '借款');
    }
});

// ==================== 协议托管 ====================
document.getElementById('enableProtocolBtn').addEventListener('click', async () => {
    try {
        showLoading('正在启用协议托管...');
        
        // 获取最大可借额度的 80%（保守策略）
        const maxBorrow = await contracts.collateralManager.getMaxBorrowAmount(state.address);
        const borrowAmount = maxBorrow.mul(80).div(100);
        
        const tx = await contracts.lendingPool.borrow(borrowAmount);
        
        console.log('✅ 协议托管借款交易:', tx.hash);
        console.log('🔗 查看交易:', `https://amoy.polygonscan.com/tx/${tx.hash}`);
        
        await tx.wait();
        
        state.debt = parseFloat(ethers.utils.formatUnits(borrowAmount, 6));
        state.isEarning = true;
        state.depositTimestamp = Date.now();
        state.earnedAmount = 0;
        state.selectedOption = 'protocol';
        
        hideModal();
        showToast('🎉 协议托管已启用');
        
        startEarningsCounter();
        await loadUserDataFromChain();
        
        // 跳转到收益管理页面
        setTimeout(() => {
            document.querySelector('[data-page="strategy"]').click();
        }, 1000);
        
    } catch (error) {
        hideModal();
        handleError(error, '启用协议托管');
    }
});

// ==================== 还款 ====================
document.getElementById('repayBtn').addEventListener('click', () => {
    showModal('偿还债务', `
        <div class="form-group">
            <label class="form-label">偿还金额 (USDC)</label>
            <div class="input-wrapper">
                <input type="number" class="form-input" id="repayAmount" placeholder="0.00" value="${state.debt.toFixed(2)}">
                <button class="input-max-btn" onclick="document.getElementById('repayAmount').value = ${state.debt.toFixed(2)}">最大</button>
            </div>
            <p style="font-size: 0.75rem; color: var(--text-muted); margin-top: 0.5rem;">
                当前债务: $${formatNumber(state.debt, 2)} USDC
            </p>
        </div>
        <div class="action-buttons mt-2">
            <button class="btn btn-secondary" onclick="hideModal()">取消</button>
            <button class="btn btn-primary" onclick="executeRepay()">确认偿还</button>
        </div>
    `);
});

window.executeRepay = async function() {
    const amount = parseFloat(document.getElementById('repayAmount').value);
    
    if (!amount || amount <= 0) {
        showToast('请输入有效金额', 'warning');
        return;
    }
    
    try {
        showLoading('步骤 1/2: 授权 USDC...');
        
        const amountWei = ethers.utils.parseUnits(amount.toString(), 6);
        const tx1 = await contracts.usdc.approve(CONTRACTS.LendingPool, amountWei);
        await tx1.wait();
        
        showLoading('步骤 2/2: 偿还债务...');
        
        const tx2 = await contracts.lendingPool.repay(amountWei);
        console.log('✅ 还款交易:', tx2.hash);
        console.log('🔗 查看交易:', `https://amoy.polygonscan.com/tx/${tx2.hash}`);
        
        await tx2.wait();
        
        state.debt = Math.max(0, state.debt - amount);
        
        if (state.debt === 0) {
            state.isEarning = false;
            if (earningsInterval) {
                clearInterval(earningsInterval);
                earningsInterval = null;
            }
        }
        
        hideModal();
        showToast('✅ 债务偿还成功');
        
        await loadUserDataFromChain();
        updateUI();
        
    } catch (error) {
        hideModal();
        handleError(error, '还款');
    }
};

// ==================== 终止仓位 ====================
document.getElementById('terminateBtn').addEventListener('click', terminatePosition);
document.getElementById('terminateSelfBtn').addEventListener('click', terminatePosition);

function terminatePosition() {
    const collateralValue = state.collateral * state.currentPrice;
    
    showModal('终止仓位', `
        <div style="text-align: center; padding: var(--spacing-lg);">
            <p style="color: var(--text-secondary); margin-bottom: var(--spacing-lg);">
                这将偿还所有债务并取回抵押品
            </p>
            <div style="background: var(--bg-elevated); border-radius: 12px; padding: var(--spacing-md); margin-bottom: var(--spacing-lg);">
                <div style="display: grid; gap: var(--spacing-sm); text-align: left;">
                    <div style="display: flex; justify-content: space-between;">
                        <span style="color: var(--text-muted);">待偿还债务</span>
                        <span style="color: var(--text-primary); font-weight: 600;">$${formatNumber(state.debt, 2)}</span>
                    </div>
                    <div style="display: flex; justify-content: space-between;">
                        <span style="color: var(--text-muted);">抵押品数量</span>
                        <span style="color: var(--accent-green); font-weight: 600;">${formatNumber(state.collateral, 2)} 代币</span>
                    </div>
                    <div style="display: flex; justify-content: space-between;">
                        <span style="color: var(--text-muted);">抵押品价值</span>
                        <span style="color: var(--accent-green); font-weight: 600;">$${formatNumber(collateralValue, 2)}</span>
                    </div>
                </div>
            </div>
            <div class="action-buttons">
                <button class="btn btn-secondary" onclick="hideModal()">取消</button>
                <button class="btn btn-danger" onclick="executeTerminate()">确认终止</button>
            </div>
        </div>
    `);
}

window.executeTerminate = async function() {
    try {
        let step = 1;
        const totalSteps = state.debt > 0 ? 4 : 2;
        
        // Step 1: 还清债务（如果有）
        if (state.debt > 0) {
            showLoading(`步骤 ${step}/${totalSteps}: 授权 USDC...`);
            
            const debtWei = ethers.utils.parseUnits(state.debt.toString(), 6);
            const tx1 = await contracts.usdc.approve(CONTRACTS.LendingPool, debtWei);
            await tx1.wait();
            step++;
            
            showLoading(`步骤 ${step}/${totalSteps}: 偿还债务...`);
            
            const tx2 = await contracts.lendingPool.repay(debtWei);
            await tx2.wait();
            step++;
        }
        
        showLoading(`步骤 ${step}/${totalSteps}: 取回抵押品...`);
        
        // Step 2: 取回抵押品
        const collateralWei = ethers.utils.parseUnits(state.collateral.toString(), 18);
        const tx3 = await contracts.collateralManager.withdrawCollateral(
            state.selectedVaultAddress,
            collateralWei
        );
        await tx3.wait();
        step++;
        
        showLoading(`步骤 ${step}/${totalSteps}: 从 Vault 取回 CTF...`);
        
        // Step 3: 从 Vault 取回 CTF
        const vault = state.selectedVault === 'YES' ? contracts.vaultYES : contracts.vaultNO;
        const tx4 = await vault.withdraw(collateralWei, state.address, state.address);
        console.log('✅ 终止交易:', tx4.hash);
        console.log('🔗 查看交易:', `https://amoy.polygonscan.com/tx/${tx4.hash}`);
        
        await tx4.wait();
        
        // 重置状态
        state.debt = 0;
        state.collateral = 0;
        state.isEarning = false;
        state.depositTimestamp = null;
        state.earnedAmount = 0;
        state.selectedOption = null;
        
        if (earningsInterval) {
            clearInterval(earningsInterval);
            earningsInterval = null;
        }
        
        hideModal();
        showToast('🎉 仓位终止成功，资金已返还');
        
        await loadUserDataFromChain();
        
        setTimeout(() => {
            document.querySelector('[data-page="deposit"]').click();
        }, 1500);
        
    } catch (error) {
        hideModal();
        handleError(error, '终止仓位');
    }
};

// ==================== 收益计算 ====================
function startEarningsCounter() {
    if (!state.isEarning || earningsInterval) return;
    
    console.log('🚀 启动收益计算器');
    
    const APY = 0.125; // 12.5%
    const secondsPerYear = 365.25 * 24 * 60 * 60;
    const ratePerSecond = APY / secondsPerYear;
    
    updateDepositTimer();
    
    earningsInterval = setInterval(() => {
        if (state.debt > 0 && state.isEarning) {
            const increment = state.debt * ratePerSecond;
            state.earnedAmount += increment;
            
            const totalEarnedEl = document.getElementById('totalEarned');
            if (totalEarnedEl) {
                totalEarnedEl.textContent = '+$' + formatNumber(state.earnedAmount, 4);
            }
        }
    }, 1000);
}

function updateDepositTimer() {
    const timerEl = document.getElementById('depositTimer');
    if (!timerEl) return;
    
    setInterval(() => {
        if (state.depositTimestamp) {
            const elapsed = Date.now() - state.depositTimestamp;
            const seconds = Math.floor(elapsed / 1000);
            const minutes = Math.floor(seconds / 60);
            const hours = Math.floor(minutes / 60);
            const days = Math.floor(hours / 24);
            
            let timeStr = '';
            if (days > 0) {
                timeStr = `${days}天 ${hours % 24}时 ${minutes % 60}分`;
            } else if (hours > 0) {
                timeStr = `${hours}时 ${minutes % 60}分 ${seconds % 60}秒`;
            } else if (minutes > 0) {
                timeStr = `${minutes}分 ${seconds % 60}秒`;
            } else {
                timeStr = `${seconds}秒`;
            }
            
            timerEl.textContent = timeStr;
        }
    }, 1000);
}

// ==================== 页面导航 ====================
document.querySelectorAll('.page-nav-item').forEach(item => {
    item.addEventListener('click', () => {
        const page = item.dataset.page;
        
        document.querySelectorAll('.page-nav-item').forEach(i => i.classList.remove('active'));
        item.classList.add('active');
        
        document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
        document.getElementById(page + 'Page').classList.add('active');
    });
});

// ==================== 更新 UI ====================
function updateUI() {
    // 健康因子
    if (state.debt > 0) {
        const hf = state.healthFactor;
        document.getElementById('healthFactor').textContent = hf.toFixed(2);
        
        if (hf < 1.2) {
            document.getElementById('healthFactor').className = 'health-value danger';
            document.getElementById('healthStatus').textContent = '危险 - 有清算风险';
            document.getElementById('healthBarFill').style.width = '30%';
        } else if (hf < 1.5) {
            document.getElementById('healthFactor').className = 'health-value warning';
            document.getElementById('healthStatus').textContent = '警告 - 健康因子偏低';
            document.getElementById('healthBarFill').style.width = '60%';
        } else {
            document.getElementById('healthFactor').className = 'health-value safe';
            document.getElementById('healthStatus').textContent = '安全 - 健康仓位';
            document.getElementById('healthBarFill').style.width = '100%';
        }
    } else {
        document.getElementById('healthFactor').textContent = '∞';
        document.getElementById('healthFactor').className = 'health-value safe';
        document.getElementById('healthStatus').textContent = '安全 - 无债务';
        document.getElementById('healthBarFill').style.width = '100%';
    }
    
    // 更新统计数据
    const collateralValue = state.collateral * state.currentPrice;
    document.getElementById('lockedCollateral').textContent = formatNumber(state.collateral, 2);
    document.getElementById('collateralValue').textContent = '$' + formatNumber(collateralValue, 2);
    
    document.getElementById('totalCollateralValue').textContent = '$' + formatNumber(collateralValue, 2);
    document.getElementById('totalDebt').textContent = '$' + formatNumber(state.debt, 2);
    
    // 可借额度 = 抵押品价值 * LTV - 当前债务
    const maxPossibleBorrow = collateralValue * 0.6; // 60% LTV
    const availableBorrow = Math.max(0, maxPossibleBorrow - state.debt);
    document.getElementById('maxBorrowAvailable').textContent = '$' + formatNumber(availableBorrow, 2);
}

// ==================== Modal 关闭 ====================
document.getElementById('modalClose').addEventListener('click', hideModal);
document.getElementById('modalOverlay').addEventListener('click', (e) => {
    if (e.target === e.currentTarget) hideModal();
});

// ==================== 初始化 ====================
console.log('🚀 Accrue DApp 已加载');
console.log('📝 合约地址配置完成');
console.log('🔗 网络: Polygon Amoy Testnet (Chain ID: 80002)');
console.log('💡 请连接钱包开始使用');

updateUI();
