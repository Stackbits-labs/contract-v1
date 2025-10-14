# StackBits Token Vault - Refactored Architecture

## 🏗️ **Refactored Structure Overview**

Contract develop to **6 sections** clear with **clean separation of concerns**:

```
📋 INTERFACES SECTION
├── IERC20 - wBTC interface  
├── IVesu - Vesu protocol interface
└── IStackBitsToken - Main contract interface

🏗️ MAIN CONTRACT
├── 👑 ADMIN SECTION
├── ⚙️ VAULT CONFIGURATION SECTION  
├── 🪙 ERC20 TOKEN DATA SECTION
├── 📈 YIELD DISTRIBUTION SECTION
├── 👥 HOLDER TRACKING SECTION
└── Events & Constructor

🔧 INTERNAL IMPLEMENTATIONS
├── 🏦 VaultInternalImpl - Vault operations
├── 📈 YieldInternalImpl - Yield distribution
└── 🪙 TokenInternalImpl - Token operations
```

## 🎯 **Key Improvements**

### **1. Clear Separation of Concerns**
```cairo
// Each section handles specific responsibility:
VaultInternalImpl    → wBTC deposits, Vesu integration
YieldInternalImpl    → Daily yield calculation & distribution  
TokenInternalImpl    → ERC20 operations, holder tracking
```

### **2. Modular Internal Functions**
```cairo
// Vault operations broken down:
_vault_deposit()
├── _handle_wbtc_deposit()     // wBTC transfer from user
├── _deposit_to_vesu()         // Deposit to Vesu protocol
├── _mint_shares()             // Mint sbwBTC tokens
└── _update_deposit_tracking() // Update accounting

_vault_withdraw()
├── _calculate_withdrawal_assets() // Calculate proportional assets
├── _withdraw_from_vesu()          // Withdraw from Vesu
├── _burn_shares()                 // Burn sbwBTC tokens  
├── _update_withdrawal_tracking()  // Update accounting
└── _transfer_wbtc_to_user()      // Transfer wBTC to user
```

### **3. Clean Yield Distribution Logic**
```cairo
_distribute_yield()
├── _can_distribute()          // Check 24h cooldown
├── _calculate_yield()         // Calculate total/protocol/user yield
├── _accumulate_protocol_fees() // Store protocol fees
├── _mint_yield_tokens()       // Mint tokens to all holders
└── _update_deposited_after_yield() // Update accounting
```

### **4. Efficient Token Management**
```cairo
TokenInternalImpl
├── _mint_shares()     // Mint with automatic holder tracking
├── _burn_shares()     // Burn with automatic holder cleanup
├── _transfer()        // Transfer with holder updates
├── _add_holder()      // Add to holder list
└── _remove_holder()   // Remove from holder list
```

## 📊 **Storage Organization**

### **Admin Section**
```cairo
owner: ContractAddress,     // Contract owner
paused: bool,              // Pause state
```

### **Vault Configuration**  
```cairo
wbtc_token: ContractAddress,  // wBTC contract address
vesu_vault: ContractAddress,  // Vesu vault address
```

### **ERC20 Data**
```cairo
name: ByteArray,           // "StackBits wBTC Vault Token"
symbol: ByteArray,         // "sbwBTC"
decimals: u8,              // 8 (same as wBTC)
total_supply: u256,        // Total sbwBTC supply
balances: Map<Address, u256>,    // User balances
allowances: Map<(Address,Address), u256>, // ERC20 allowances
```

### **Yield Distribution**
```cairo
last_yield_distribution: u64,    // Last distribution timestamp
total_wbtc_deposited: u256,      // Original deposits (for calculation)
protocol_fee_percentage: u256,   // Fee % (scaled by 10000)
accumulated_fees: u256,          // Fees ready for collection
```

### **Holder Tracking**
```cairo
holders: Map<u256, Address>,     // Index → holder address
holder_count: u256,              // Total unique holders
is_holder: Map<Address, bool>,   // Quick holder lookup
```

## 🔄 **Function Flow Examples**

### **Deposit Flow**
```cairo
deposit(assets) 
    → _vault_deposit(assets)
        → _handle_wbtc_deposit(user, assets)    // Transfer wBTC
        → _deposit_to_vesu(assets)              // Deposit to Vesu
        → _mint_shares(user, assets)            // Mint 1:1 sbwBTC
            → _add_holder(user)                 // Track holder
        → _update_deposit_tracking(assets)      // Update accounting
        → emit Deposit event
```

### **Yield Distribution Flow**
```cairo
distribute_daily_yield()
    → _distribute_yield()
        → _can_distribute()                     // Check 24h passed
        → _calculate_yield()                    // Get yield amounts
        → _accumulate_protocol_fees(fees)       // Store protocol fees
        → _mint_yield_tokens(user_yield)        // Mint to all holders
            → for each holder:
                → _mint_yield_to_holder()       // Proportional mint
        → _update_deposited_after_yield()       // Update accounting
        → emit YieldDistributed event
```

### **Withdraw Flow**
```cairo
withdraw(shares)
    → _vault_withdraw(shares)
        → _calculate_withdrawal_assets(shares)  // Calculate wBTC amount
        → _withdraw_from_vesu(assets)           // Withdraw from Vesu
        → _burn_shares(user, shares)            // Burn sbwBTC
            → _remove_holder(user)              // Update holder tracking
        → _update_withdrawal_tracking(shares)   // Update accounting
        → _transfer_wbtc_to_user(user, assets) // Send wBTC
        → emit Withdraw event
```

## 🛡️ **Security Features**

### **Input Validation**
- All functions validate inputs (non-zero amounts, sufficient balances)
- Owner-only functions check caller permissions
- Zero address protection in all token operations

### **State Consistency**
- Atomic operations ensure consistent state
- Holder tracking automatically maintained
- Accounting always balanced (deposits = withdrawals + fees + yield)

### **Access Control**
- Pausable functionality for emergencies
- Owner-only admin functions
- Protocol fee capped at 50%

## 🎨 **Benefits of Refactored Architecture**

### **1. Maintainability**
- Each section has single responsibility
- Easy to locate and fix issues
- Clean code structure for audits

### **2. Readability**
- Clear function names describe exact purpose
- Logical grouping of related functionality
- Comprehensive comments explain each section

### **3. Testability**
- Internal functions can be tested independently
- Clear separation makes unit testing easier
- Predictable state transitions

### **4. Extensibility**
- Easy to add new features to specific sections
- Internal functions can be reused
- Modular design supports future upgrades

## 🚀 **Usage Remains the Same**

Despite internal refactoring, **public interface unchanged**:

```javascript
// Users interact exactly the same way:
await wbtc.approve(vault.address, amount);
await vault.deposit(amount);              // Get sbwBTC 1:1
await vault.distribute_daily_yield();     // Anyone can call
await vault.withdraw(shares);             // Get wBTC + yield

// View functions work the same:
await vault.balance_of(user);
await vault.get_pending_yield();
await vault.can_distribute_yield();
```

## 📁 **File Structure**

```
src/
├── lib.cairo                    // Module exports
├── token_vault.cairo           // Original version
└── token_vault_refactored.cairo // ✨ New refactored version
```

**Recommendation**: Use `token_vault_refactored.cairo` for production deployment due to improved architecture and maintainability!

## 🔧 **Deployment**

Same constructor parameters:
```cairo
constructor(
    owner: ContractAddress,        // Your admin address
    wbtc_token: ContractAddress,   // wBTC contract address  
    vesu_vault: ContractAddress,   // Vesu vault address
)
```

The refactored version provides the **same functionality** with **much better code organization** for long-term maintenance and development!
