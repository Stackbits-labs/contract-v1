use starknet::ContractAddress;

// ============================================
// 📋 INTERFACES SECTION
// ============================================

// ERC20 Interface for wBTC and other tokens
#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer_from(
        ref self: TContractState, 
        sender: ContractAddress, 
        recipient: ContractAddress, 
        amount: u256
    ) -> bool;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

// Vesu Protocol Interface
#[starknet::interface]
trait IVesu<TContractState> {
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    fn withdraw(ref self: TContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256;
    fn redeem(ref self: TContractState, shares: u256, receiver: ContractAddress, owner: ContractAddress) -> u256;
    fn max_redeem(self: @TContractState, owner: ContractAddress) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

// Main contract interface combining ERC20 + Vault + Yield functions
#[starknet::interface]
trait IStackBitsToken<TContractState> {
    // ERC20 standard functions
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, 
        sender: ContractAddress, 
        recipient: ContractAddress, 
        amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    
    // Vault functions - User facing
    fn deposit_wbtc(ref self: TContractState, assets: u256) -> u256;
    fn withdraw_wbtc(ref self: TContractState, shares: u256) -> u256;
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_total_wbtc_deposited(self: @TContractState) -> u256;
    
    // Yield distribution functions
    fn distribute_daily_yield(ref self: TContractState) -> bool;
    fn can_distribute_yield(self: @TContractState) -> bool;
    fn get_last_yield_distribution(self: @TContractState) -> u64;
    fn get_pending_yield(self: @TContractState) -> u256;
    
    // Admin functions
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn set_protocol_fee(ref self: TContractState, fee_percentage: u256);
    fn collect_fees(ref self: TContractState) -> u256;
    fn get_accumulated_fees(self: @TContractState) -> u256;
}

// ============================================
// 🏗️ MAIN CONTRACT
// ============================================

#[starknet::contract]
mod StackBitsTokenVault {
    use super::IERC20DispatcherTrait;
    use super::IERC20Dispatcher;
    use super::IVesuDispatcherTrait;
    use super::IVesuDispatcher;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess
    };

    const ZERO_ADDRESS: felt252 = 0;

    #[storage]
    struct Storage {
        // ============================================
        // 👑 ADMIN SECTION
        // ============================================
        owner: ContractAddress,
        paused: bool,
        
        // ============================================
        // ⚙️ VAULT CONFIGURATION SECTION
        // ============================================
        wbtc_token: ContractAddress,
        vesu_vault: ContractAddress,
        
        // ============================================
        // 🪙 ERC20 TOKEN DATA SECTION
        // ============================================
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        
        // ============================================
        // 📈 YIELD DISTRIBUTION SECTION
        // ============================================
        last_yield_distribution: u64, // timestamp of last distribution
        total_wbtc_deposited: u256, // total wBTC deposited by users
        protocol_fee_percentage: u256, // fee percentage (scaled by 10000, so 1000 = 10%)
        accumulated_fees: u256, // accumulated protocol fees
        
        // ============================================
        // 👥 HOLDER TRACKING SECTION
        // ============================================
        holders: Map<u256, ContractAddress>, // index -> address
        holder_count: u256, // total number of holders
        is_holder: Map<ContractAddress, bool>, // address -> is_holder
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        Deposit: Deposit,
        Withdraw: Withdraw,
        YieldDistributed: YieldDistributed,
        FeesCollected: FeesCollected,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        user: ContractAddress,
        assets: u256,
        shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        user: ContractAddress,
        assets: u256,
        shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct YieldDistributed {
        total_yield: u256,
        protocol_fees: u256,
        user_yield: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct FeesCollected {
        #[key]
        recipient: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        wbtc_token: ContractAddress,
        vesu_vault: ContractAddress,
    ) {
        // Admin setup
        self.owner.write(owner);
        self.paused.write(false);
        
        // Vault configuration
        self.wbtc_token.write(wbtc_token);
        self.vesu_vault.write(vesu_vault);
        
        // Token metadata
        self.name.write("StackBits wBTC Vault Token");
        self.symbol.write("sbwBTC");
        self.decimals.write(8); // Same as wBTC
        self.total_supply.write(0);
        
        // Yield distribution settings
        self.last_yield_distribution.write(0);
        self.total_wbtc_deposited.write(0);
        self.protocol_fee_percentage.write(1000); // 10% fee
        self.accumulated_fees.write(0);
        self.holder_count.write(0);
    }

    // ============================================
    // 🪙 ERC20 TOKEN SECTION
    // ============================================
    #[abi(embed_v0)]
    impl StackBitsTokenImpl of super::IStackBitsToken<ContractState> {
        // Pure ERC20 functions
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._transfer(caller, to, amount);
            true
        }

        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((sender, caller));
            assert!(current_allowance >= amount, "ERC20: transfer amount exceeds allowance");
            
            self.allowances.write((sender, caller), current_allowance - amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
            
            self.emit(Event::Approval(Approval {
                owner: caller,
                spender,
                value: amount,
            }));
            true
        }

        // ============================================
        // 🏦 VAULT POOL SECTION  
        // ============================================
        
        fn deposit_wbtc(ref self: ContractState, assets: u256) -> u256 {
            self._vault_deposit(assets)
        }

        fn withdraw_wbtc(ref self: ContractState, shares: u256) -> u256 {
            self._vault_withdraw(shares)
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            self._get_vesu_total_assets()
        }

        fn get_total_wbtc_deposited(self: @ContractState) -> u256 {
            self.total_wbtc_deposited.read()
        }

        // ============================================
        // 📈 YIELD DISTRIBUTION SECTION
        // ============================================
        
        fn distribute_daily_yield(ref self: ContractState) -> bool {
            self._distribute_yield()
        }

        fn can_distribute_yield(self: @ContractState) -> bool {
            self._can_distribute()
        }

        fn get_last_yield_distribution(self: @ContractState) -> u64 {
            self.last_yield_distribution.read()
        }

        fn get_pending_yield(self: @ContractState) -> u256 {
            let total_vesu_assets = self.get_total_assets();
            let total_deposited = self.total_wbtc_deposited.read();
            
            if total_vesu_assets > total_deposited {
                total_vesu_assets - total_deposited
            } else {
                0
            }
        }

        // ============================================
        // 👑 ADMIN SECTION
        // ============================================

        fn pause(ref self: ContractState) {
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can pause");
            self.paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can unpause");
            self.paused.write(false);
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn set_protocol_fee(ref self: ContractState, fee_percentage: u256) {
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can set fee");
            assert!(fee_percentage <= 5000, "Fee cannot exceed 50%"); // Max 50% fee
            
            self.protocol_fee_percentage.write(fee_percentage);
        }

        fn collect_fees(ref self: ContractState) -> u256 {
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can collect fees");
            
            let fees = self.accumulated_fees.read();
            if fees == 0 {
                return 0;
            }
            
            // Withdraw fees from Vesu and transfer to owner
            self._withdraw_fees_from_vesu(fees);
            self._transfer_fees_to_owner(caller, fees);
            
            // Reset accumulated fees
            self.accumulated_fees.write(0);
            
            self.emit(Event::FeesCollected(FeesCollected {
                recipient: caller,
                amount: fees,
            }));
            
            fees
        }

        fn get_accumulated_fees(self: @ContractState) -> u256 {
            self.accumulated_fees.read()
        }
    }

    // ============================================
    // 🏦 VAULT INTERNAL IMPLEMENTATIONS
    // ============================================
    
    #[generate_trait]
    impl VaultInternalImpl of VaultInternalTrait {
        fn _vault_deposit(ref self: ContractState, assets: u256) -> u256 {
            assert!(!self.paused.read(), "Contract is paused");
            assert!(assets > 0, "Cannot deposit zero assets");
            
            let caller = get_caller_address();
            
            // Step 1-3: Handle wBTC transfer and Vesu deposit
            self._handle_wbtc_deposit(caller, assets);
            self._deposit_to_vesu(assets);
            
            // Step 4-5: Mint tokens and update tracking
            self._mint_shares(caller, assets);
            self._update_deposit_tracking(assets);
            
            // Emit event
            self.emit(Event::Deposit(Deposit {
                user: caller,
                assets,
                shares: assets, // 1:1 ratio
            }));
            
            assets // 1:1 ratio
        }

        fn _vault_withdraw(ref self: ContractState, shares: u256) -> u256 {
            assert!(!self.paused.read(), "Contract is paused");
            assert!(shares > 0, "Cannot withdraw zero shares");
            
            let caller = get_caller_address();
            let user_balance = self.balances.read(caller);
            assert!(user_balance >= shares, "Insufficient balance");
            
            // Calculate proportional assets to withdraw
            let assets = self._calculate_withdrawal_assets(shares);
            
            // Execute withdrawal
            self._withdraw_from_vesu(assets);
            self._burn_shares(caller, shares);
            self._update_withdrawal_tracking(shares);
            self._transfer_wbtc_to_user(caller, assets);
            
            // Emit event
            self.emit(Event::Withdraw(Withdraw {
                user: caller,
                assets,
                shares,
            }));
            
            assets
        }

        fn _handle_wbtc_deposit(ref self: ContractState, user: ContractAddress, amount: u256) {
            let vault_address = get_contract_address();
            let wbtc_token = self.wbtc_token.read();
            let wbtc_contract = IERC20Dispatcher { contract_address: wbtc_token };
            
            // Transfer wBTC from user to vault
            let transfer_success = wbtc_contract.transfer_from(user, vault_address, amount);
            assert!(transfer_success, "wBTC transfer failed");
        }

        fn _deposit_to_vesu(ref self: ContractState, amount: u256) {
            let vault_address = get_contract_address();
            let wbtc_token = self.wbtc_token.read();
            let vesu_vault = self.vesu_vault.read();
            
            // Approve wBTC to Vesu vault
            let wbtc_contract = IERC20Dispatcher { contract_address: wbtc_token };
            let approve_success = wbtc_contract.approve(vesu_vault, amount);
            assert!(approve_success, "wBTC approval failed");
            
            // Deposit wBTC to Vesu vault
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            let _vesu_shares = vesu_contract.deposit(amount, vault_address);
        }

        fn _calculate_withdrawal_assets(self: @ContractState, shares: u256) -> u256 {
            let total_supply = self.total_supply.read();
            let total_vesu_assets = self._get_vesu_total_assets();
            (shares * total_vesu_assets) / total_supply
        }

        fn _withdraw_from_vesu(ref self: ContractState, assets: u256) {
            let vault_address = get_contract_address();
            let vesu_vault = self.vesu_vault.read();
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            
            let max_assets = vesu_contract.max_withdraw(vault_address);
            assert!(assets <= max_assets, "Insufficient Vesu assets");
            
            let _vesu_shares_burned = vesu_contract.withdraw(assets, vault_address, vault_address);
        }

        fn _transfer_wbtc_to_user(ref self: ContractState, user: ContractAddress, amount: u256) {
            let wbtc_token = self.wbtc_token.read();
            let wbtc_contract = IERC20Dispatcher { contract_address: wbtc_token };
            let transfer_success = wbtc_contract.transfer(user, amount);
            assert!(transfer_success, "wBTC transfer failed");
        }

        fn _update_deposit_tracking(ref self: ContractState, assets: u256) {
            let current_deposited = self.total_wbtc_deposited.read();
            self.total_wbtc_deposited.write(current_deposited + assets);
        }

        fn _update_withdrawal_tracking(ref self: ContractState, shares: u256) {
            let total_supply = self.total_supply.read();
            let current_deposited = self.total_wbtc_deposited.read();
            let deposited_to_reduce = (shares * current_deposited) / total_supply;
            self.total_wbtc_deposited.write(current_deposited - deposited_to_reduce);
        }

        fn _get_vesu_total_assets(self: @ContractState) -> u256 {
            let vault_address = get_contract_address();
            let vesu_vault = self.vesu_vault.read();
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            
            // Get current Vesu shares owned by vault  
            let vesu_shares = vesu_contract.balance_of(vault_address);
            
            // Convert Vesu shares to assets (includes yield)
            vesu_contract.convert_to_assets(vesu_shares)
        }

        fn _withdraw_fees_from_vesu(ref self: ContractState, fees: u256) {
            let vault_address = get_contract_address();
            let vesu_vault = self.vesu_vault.read();
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            
            let max_assets = vesu_contract.max_withdraw(vault_address);
            assert!(fees <= max_assets, "Insufficient assets in Vesu");
            
            let _vesu_shares_burned = vesu_contract.withdraw(fees, vault_address, vault_address);
        }

        fn _transfer_fees_to_owner(ref self: ContractState, owner: ContractAddress, fees: u256) {
            let wbtc_token = self.wbtc_token.read();
            let wbtc_contract = IERC20Dispatcher { contract_address: wbtc_token };
            let transfer_success = wbtc_contract.transfer(owner, fees);
            assert!(transfer_success, "Fee transfer failed");
        }
    }

    // ============================================
    // 📈 YIELD INTERNAL IMPLEMENTATIONS
    // ============================================
    
    #[generate_trait] 
    impl YieldInternalImpl of YieldInternalTrait {
        fn _distribute_yield(ref self: ContractState) -> bool {
            assert!(self._can_distribute(), "Cannot distribute yield yet");
            
            let current_time = get_block_timestamp();
            let (total_yield, protocol_fees, user_yield) = self._calculate_yield();
            
            // No yield to distribute
            if total_yield == 0 {
                self.last_yield_distribution.write(current_time);
                return false;
            }
            
            // Accumulate protocol fees
            self._accumulate_protocol_fees(protocol_fees);
            
            // Distribute yield to users by minting tokens
            if user_yield > 0 && self.total_supply.read() > 0 {
                self._mint_yield_tokens(user_yield);
                self._update_deposited_after_yield(user_yield);
            }
            
            self.last_yield_distribution.write(current_time);
            
            self.emit(Event::YieldDistributed(YieldDistributed {
                total_yield,
                protocol_fees,
                user_yield,
                timestamp: current_time,
            }));
            
            true
        }

        fn _can_distribute(self: @ContractState) -> bool {
            let current_time = get_block_timestamp();
            let last_distribution = self.last_yield_distribution.read();
            
            // Check if 24 hours (86400 seconds) have passed
            current_time >= last_distribution + 86400
        }

        fn _calculate_yield(self: @ContractState) -> (u256, u256, u256) {
            let total_vesu_assets = self._get_vesu_total_assets();
            let total_deposited = self.total_wbtc_deposited.read();
            
            if total_vesu_assets <= total_deposited {
                return (0, 0, 0);
            }
            
            let total_yield = total_vesu_assets - total_deposited;
            let fee_percentage = self.protocol_fee_percentage.read();
            let protocol_fees = (total_yield * fee_percentage) / 10000;
            let user_yield = total_yield - protocol_fees;
            
            (total_yield, protocol_fees, user_yield)
        }

        fn _accumulate_protocol_fees(ref self: ContractState, protocol_fees: u256) {
            let current_fees = self.accumulated_fees.read();
            self.accumulated_fees.write(current_fees + protocol_fees);
        }

        fn _mint_yield_tokens(ref self: ContractState, user_yield: u256) {
            let holder_count = self.holder_count.read();
            let total_deposited = self.total_wbtc_deposited.read();
            
            // Mint tokens proportionally to all holders
            let mut i: u256 = 0;
            while i != holder_count {
                let holder = self.holders.read(i);
                if self.is_holder.read(holder) {
                    let holder_balance = self.balances.read(holder);
                    if holder_balance > 0 {
                        // Calculate proportional yield tokens to mint
                        let holder_yield_tokens = (holder_balance * user_yield) / total_deposited;
                        if holder_yield_tokens > 0 {
                            self._mint_yield_to_holder(holder, holder_yield_tokens);
                        }
                    }
                }
                i += 1;
            }
        }

        fn _mint_yield_to_holder(ref self: ContractState, holder: ContractAddress, amount: u256) {
            let zero_address: ContractAddress = ZERO_ADDRESS.try_into().unwrap();
            let holder_balance = self.balances.read(holder);
            let new_holder_balance = holder_balance + amount;
            self.balances.write(holder, new_holder_balance);
            
            // Update total supply
            let new_total_supply = self.total_supply.read() + amount;
            self.total_supply.write(new_total_supply);
            
            // Emit transfer event
            self.emit(Event::Transfer(Transfer {
                from: zero_address,
                to: holder,
                value: amount,
            }));
        }

        fn _update_deposited_after_yield(ref self: ContractState, user_yield: u256) {
            let total_deposited = self.total_wbtc_deposited.read();
            let new_deposited = total_deposited + user_yield;
            self.total_wbtc_deposited.write(new_deposited);
        }
    }

    // ============================================
    // 🪙 TOKEN INTERNAL IMPLEMENTATIONS
    // ============================================
    
    #[generate_trait]
    impl TokenInternalImpl of TokenInternalTrait {
        fn _mint_shares(ref self: ContractState, to: ContractAddress, amount: u256) {
            let zero_address: ContractAddress = ZERO_ADDRESS.try_into().unwrap();
            assert!(to != zero_address, "ERC20: mint to the zero address");

            let current_supply = self.total_supply.read();
            self.total_supply.write(current_supply + amount);
            
            let to_balance = self.balances.read(to);
            let new_balance = to_balance + amount;
            self.balances.write(to, new_balance);
            
            // Track holder if this is their first tokens
            if to_balance == 0 && new_balance > 0 {
                self._add_holder(to);
            }

            self.emit(Event::Transfer(Transfer {
                from: zero_address,
                to,
                value: amount,
            }));
        }

        fn _burn_shares(ref self: ContractState, from: ContractAddress, amount: u256) {
            let zero_address: ContractAddress = ZERO_ADDRESS.try_into().unwrap();
            assert!(from != zero_address, "ERC20: burn from the zero address");

            let from_balance = self.balances.read(from);
            assert!(from_balance >= amount, "ERC20: burn amount exceeds balance");

            let new_balance = from_balance - amount;
            self.balances.write(from, new_balance);
            
            // Remove holder if they have no tokens left
            if new_balance == 0 {
                self._remove_holder(from);
            }
            
            let current_supply = self.total_supply.read();
            self.total_supply.write(current_supply - amount);

            self.emit(Event::Transfer(Transfer {
                from,
                to: zero_address,
                value: amount,
            }));
        }

        fn _transfer(ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256) {
            let zero_address: ContractAddress = ZERO_ADDRESS.try_into().unwrap();
            assert!(from != zero_address, "ERC20: transfer from the zero address");
            assert!(to != zero_address, "ERC20: transfer to the zero address");

            let from_balance = self.balances.read(from);
            assert!(from_balance >= amount, "ERC20: transfer amount exceeds balance");

            let new_from_balance = from_balance - amount;
            self.balances.write(from, new_from_balance);
            
            let to_balance = self.balances.read(to);
            let new_to_balance = to_balance + amount;
            self.balances.write(to, new_to_balance);
            
            // Update holder tracking
            if new_from_balance == 0 {
                self._remove_holder(from);
            }
            if to_balance == 0 && new_to_balance > 0 {
                self._add_holder(to);
            }

            self.emit(Event::Transfer(Transfer {
                from,
                to,
                value: amount,
            }));
        }

        fn _add_holder(ref self: ContractState, holder: ContractAddress) {
            if !self.is_holder.read(holder) {
                let count = self.holder_count.read();
                self.holders.write(count, holder);
                self.is_holder.write(holder, true);
                self.holder_count.write(count + 1);
            }
        }

        fn _remove_holder(ref self: ContractState, holder: ContractAddress) {
            if self.is_holder.read(holder) {
                self.is_holder.write(holder, false);
                // Note: For gas efficiency, we don't compact the holders array
                // We just mark them as not a holder
            }
        }
    }
}
