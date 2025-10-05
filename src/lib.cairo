use starknet::ContractAddress;

// wBTC Token Addresses: 0x04861ba938aed21f2cd7740acd3765ac4d2974783a3218367233de0153490cb6
// Sepolia Testnet: 0x0496bef3ed20371382fBe0CA6A5a64252c5c848F9f1F0ccCF8110Fc4def912d5
// Mainnet: 0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC

// owner: ContractAddress - Địa chỉ owner của vault
// wbtc_token: ContractAddress - Địa chỉ wBTC token
// vesu_vault: ContractAddress - Địa chỉ Vesu vtoken

// Vesu Protocol Vault Addresses (you need to get these from Vesu documentation):
// Sepolia: [VESU_VAULT_ADDRESS_FOR_WBTC_SEPOLIA]
// Mainnet: [VESU_VAULT_ADDRESS_FOR_WBTC_MAINNET]

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

#[starknet::contract]
mod StackBitsVault {
    use super::IERC20DispatcherTrait;
    use super::IERC20Dispatcher;
    use super::IVesuDispatcherTrait;
    use super::IVesuDispatcher;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        wbtc_token: ContractAddress,
        vesu_vault: ContractAddress,
        total_supply: u256,
        total_assets: u256,
        paused: bool,
        balances: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        wbtc_token: ContractAddress,
        vesu_vault: ContractAddress,
    ) {
        self.owner.write(owner);
        self.wbtc_token.write(wbtc_token);
        self.vesu_vault.write(vesu_vault);
        self.total_supply.write(0);
        self.total_assets.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl VaultImpl of IVault<ContractState> {
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            self.total_assets.read()
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn get_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.balances.read(user)
        }

        fn deposit(ref self: ContractState, assets: u256) -> u256 {
            assert!(!self.paused.read(), "Contract is paused");
            assert!(assets > 0, "Cannot deposit zero assets");
            
            let caller = get_caller_address();
            let vault_address = get_contract_address();
            let wbtc_token = self.wbtc_token.read();
            let vesu_vault = self.vesu_vault.read();
            
            // Step 1: Transfer wBTC from user to this vault
            let wbtc_contract = IERC20Dispatcher { contract_address: wbtc_token };
            let transfer_success = wbtc_contract.transfer_from(caller, vault_address, assets);
            assert!(transfer_success, "wBTC transfer failed");
            
            // Step 2: Approve wBTC to Vesu vault
            let approve_success = wbtc_contract.approve(vesu_vault, assets);
            assert!(approve_success, "wBTC approval failed");
            
            // Step 3: Deposit wBTC to Vesu vault and receive Vesu shares
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            let _vesu_shares = vesu_contract.deposit(assets, vault_address);
            
            // Calculate shares based on current share price (includes yield)
            let shares = self.convert_assets_to_shares(assets);
            
            let current_supply = self.total_supply.read();
            let current_assets = self.total_assets.read();
            
            // Update state
            self.total_supply.write(current_supply + shares);
            self.total_assets.write(current_assets + assets);
            
            let user_balance = self.balances.read(caller);
            self.balances.write(caller, user_balance + shares);

            self.emit(Event::Deposit(Deposit {
                user: caller,
                assets,
                shares,
            }));

            shares
        }

        fn withdraw(ref self: ContractState, shares: u256) -> u256 {
            assert!(!self.paused.read(), "Contract is paused");
            assert!(shares > 0, "Cannot withdraw zero shares");
            
            let caller = get_caller_address();
            let user_balance = self.balances.read(caller);
            assert!(user_balance >= shares, "Insufficient balance");
            let vault_address = get_contract_address();
            let vesu_vault = self.vesu_vault.read();
            
            // Calculate assets to withdraw based on current share price (includes yield)
            let assets = self.convert_shares_to_assets(shares);
            
            // Use Vesu withdraw (specify exact assets) instead of redeem
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            let max_assets = vesu_contract.max_withdraw(vault_address);
            assert!(assets <= max_assets, "Insufficient Vesu assets");
            
            // Step 1: Withdraw exact assets from Vesu vault
            let _vesu_shares_burned = vesu_contract.withdraw(assets, vault_address, vault_address);
            
            // Step 2: Update vault state
            let current_supply = self.total_supply.read();
            let current_assets = self.total_assets.read();
            self.total_supply.write(current_supply - shares);
            self.total_assets.write(current_assets - assets);
            self.balances.write(caller, user_balance - shares);
            
            // Step 3: Transfer wBTC to user
            let wbtc_token = self.wbtc_token.read();
            let wbtc_contract = IERC20Dispatcher { contract_address: wbtc_token };
            let transfer_success = wbtc_contract.transfer(caller, assets);
            assert!(transfer_success, "wBTC transfer failed");

            self.emit(Event::Withdraw(Withdraw {
                user: caller,
                assets,
                shares,
            }));

            assets
        }

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

        fn get_wbtc_token(self: @ContractState) -> ContractAddress {
            self.wbtc_token.read()
        }

        fn get_vesu_vault(self: @ContractState) -> ContractAddress {
            self.vesu_vault.read()
        }

        fn get_vesu_position(self: @ContractState) -> u256 {
            let vault_address = get_contract_address();
            let vesu_vault = self.vesu_vault.read();
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            vesu_contract.max_redeem(vault_address)
        }

        fn get_total_vesu_assets(self: @ContractState) -> u256 {
            let vault_address = get_contract_address();
            let vesu_vault = self.vesu_vault.read();
            let vesu_contract = IVesuDispatcher { contract_address: vesu_vault };
            
            // Get current Vesu shares owned by vault  
            let vesu_shares = vesu_contract.balance_of(vault_address);
            
            // Convert Vesu shares to assets (this includes yield from Vesu)
            vesu_contract.convert_to_assets(vesu_shares)
        }

        fn get_share_price(self: @ContractState) -> u256 {
            let total_supply = self.total_supply.read();
            if total_supply == 0 {
                return 1000000; // 1.0 with 6 decimals
            }
            
            let total_assets = self.get_total_vesu_assets();
            // Share price = total_assets / total_supply (scaled by 1e6)
            (total_assets * 1000000) / total_supply
        }

        fn convert_assets_to_shares(self: @ContractState, assets: u256) -> u256 {
            let total_supply = self.total_supply.read();
            if total_supply == 0 {
                return assets; // First deposit: 1:1 ratio
            }
            
            let total_assets = self.get_total_vesu_assets();
            // shares = assets * total_supply / total_assets
            (assets * total_supply) / total_assets
        }

        fn convert_shares_to_assets(self: @ContractState, shares: u256) -> u256 {
            let total_supply = self.total_supply.read();
            if total_supply == 0 {
                return 0;
            }
            
            let total_assets = self.get_total_vesu_assets();
            // assets = shares * total_assets / total_supply
            (shares * total_assets) / total_supply
        }

        // User portfolio information
        fn get_user_portfolio(self: @ContractState, user: ContractAddress) -> (u256, u256, u256) {
            let user_shares = self.balances.read(user);
            let current_assets = self.convert_shares_to_assets(user_shares);
            let share_price = self.get_share_price();
            
            // Returns (user_shares, current_assets_value, current_share_price)
            (user_shares, current_assets, share_price)
        }
    }

    #[starknet::interface]
    trait IVault<TContractState> {
        fn get_owner(self: @TContractState) -> ContractAddress;
        fn get_total_supply(self: @TContractState) -> u256;
        fn get_total_assets(self: @TContractState) -> u256;
        fn is_paused(self: @TContractState) -> bool;
        fn get_balance(self: @TContractState, user: ContractAddress) -> u256;
        fn get_wbtc_token(self: @TContractState) -> ContractAddress;
        fn get_vesu_vault(self: @TContractState) -> ContractAddress;
        fn get_vesu_position(self: @TContractState) -> u256;
        fn get_total_vesu_assets(self: @TContractState) -> u256;
        fn get_share_price(self: @TContractState) -> u256;
        fn convert_assets_to_shares(self: @TContractState, assets: u256) -> u256;
        fn convert_shares_to_assets(self: @TContractState, shares: u256) -> u256;
        fn get_user_portfolio(self: @TContractState, user: ContractAddress) -> (u256, u256, u256);
        fn deposit(ref self: TContractState, assets: u256) -> u256;
        fn withdraw(ref self: TContractState, shares: u256) -> u256;
        fn pause(ref self: TContractState);
        fn unpause(ref self: TContractState);
    }
}