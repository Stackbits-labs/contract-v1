# StackBits Token Vault - Mainnet Deployment Guide

## 🚀 **Mainnet Deployment Parameters**

Deploy to **Starknet Mainnet**, need change **2 address** in constructor:

### **Constructor Parameters:**

```cairo
constructor(
    owner: ContractAddress,        // ✅ Your admin wallet address  
    wbtc_token: ContractAddress,   // 🔄 Change to mainnet wBTC
    vesu_vault: ContractAddress,   // 🔄 Change to mainnet Vesu vault
)
```

## 📋 **Mainnet Addresses**

### **1. wBTC Token Address (Mainnet)**
```
0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC
```

### **2. Vesu vwBTC Vault Address (Mainnet)** 
```
🔍 NEED TO FIND: Check Vesu documentation or app for mainnet vault
```

### **3. Your Owner Address**
```
Your mainnet wallet address (e.g., ArgentX, Braavos)
```

## 🔍 **How to Find Vesu Vault Address**

### **Method 1: Vesu App**
1. Go to https://app.vesu.xyz
2. Connect to Mainnet
3. Look for wBTC vault
4. Check contract address in transaction details

### **Method 2: Vesu Documentation**
1. Visit https://docs.vesu.xyz
2. Look for "Contract Addresses" section
3. Find mainnet wBTC vault address

### **Method 3: StarkScan**
1. Go to https://starkscan.co
2. Search for "Vesu" or "vwBTC"
3. Find the vault contract for wBTC

### **Method 4: Vesu GitHub**
1. Check https://github.com/vesuxyz
2. Look for deployed contracts file
3. Find mainnet addresses

## 🛠️ **Deployment Script Example**

### **Using Starknet CLI:**
```bash
# Build contract first
scarb build

# Deploy to mainnet
starknet deploy \
  --network mainnet \
  --contract target/dev/stackbits_vault_StackBitsTokenVault.contract_class.json \
  --inputs \
    0x[YOUR_OWNER_ADDRESS] \
    0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC \
    0x[VESU_VAULT_ADDRESS_FOR_WBTC_MAINNET]
```

### **Using Starknet Foundry:**
```bash
# Deploy with sncast
sncast --account=mainnet declare \
    --contract-name=StackBitsTokenVault \
    --network=mainnet

sncast --account=mainnet deploy \
    --class-hash=[CLASS_HASH_FROM_DECLARE] \
    --network=mainnet
    --constructor-calldata \
    0x[YOUR_OWNER_ADDRESS] \
    0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC \
    0x00c452bacd439bab4e39aeea190b4ff81f44b019d4b3a25fa4da04a1cae7b6ff
```

## ⚠️ **Pre-Deployment Checklist**

### **1. Verify Addresses**
- [ ] ✅ wBTC mainnet address is correct
- [ ] 🔍 Vesu vault address supports wBTC deposits
- [ ] ✅ Owner address is your mainnet wallet
- [ ] ✅ All addresses are valid Starknet addresses

### **2. Test on Testnet First**
```bash
# Testnet addresses for testing:
wBTC Testnet: 0x04861ba938aed21f2cd7740acd3765ac4d2974783a3218367233de0153490cb6
vToken Testnet: 0x033d52ef1746ab58c5a22f8e4d80eaaf7c5a08fcfaa6c5e5365680d0ed482f34
```

### **3. Contract Verification**
- [ ] ✅ Contract compiles successfully (`scarb build`)
- [ ] ✅ All tests pass
- [ ] ✅ Security audit completed (recommended)

### **4. Wallet Setup**
- [ ] ✅ Sufficient ETH for deployment gas
- [ ] ✅ Wallet connected to mainnet
- [ ] ✅ Private key securely managed

## 🔐 **Security Considerations**

### **Initial Configuration**
After deployment, the contract will have:
- **Protocol fee**: 10% (can be changed by owner)
- **Token name**: "StackBits wBTC Vault Token"
- **Token symbol**: "sbwBTC"
- **Decimals**: 8 (same as wBTC)

### **Owner Permissions**
The owner address can:
- Pause/unpause contract
- Set protocol fee (max 50%)
- Collect accumulated fees
- **⚠️ Choose owner address carefully!**

## 📊 **Post-Deployment Steps**

### **1. Verify Deployment**
```bash
# Check contract is deployed
starknet get_code --contract_address 0x[DEPLOYED_ADDRESS]

# Verify initial state
starknet call \
  --address 0x[DEPLOYED_ADDRESS] \
  --abi target/dev/stackbits_vault.contract_class.json \
  --function name
```

### **2. Test Basic Operations**
1. ✅ Check contract name/symbol
2. ✅ Verify owner address
3. ✅ Test deposit with small amount
4. ✅ Verify Vesu integration works

### **3. Frontend Integration**
Update your frontend with:
- New contract address
- Mainnet network configuration
- wBTC mainnet address for approvals

## 🌐 **Network Differences**

| Aspect | Testnet | Mainnet |
|--------|---------|---------|
| wBTC Address | `0x0496...912d5` | `0x03Fe...e7AC` |
| Vesu Vault | [Testnet Address] | [Mainnet Address] |
| Gas Costs | Free (testnet ETH) | Real ETH required |
| Risk | Low (test funds) | High (real funds) |

