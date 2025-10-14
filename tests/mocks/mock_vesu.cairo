use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockVesuVault<TContractState> {
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    fn withdraw(ref self: TContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    fn max_redeem(self: @TContractState, owner: ContractAddress) -> u256;
    fn simulate_yield(ref self: TContractState, yield_percentage: u256);
}

#[starknet::contract]
pub mod MockVesuVault {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        vault_assets: u256,
        vault_shares: u256,
        asset_to_share_ratio: u256, // Scaled by 1000000 (6 decimals)
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.asset_to_share_ratio.write(1000000); // 1:1 ratio initially
    }

    #[abi(embed_v0)]
    impl MockVesuVaultImpl of super::IMockVesuVault<ContractState> {
        fn deposit(ref self: ContractState, assets: u256, receiver: ContractAddress) -> u256 {
            let current_assets = self.vault_assets.read();
            self.vault_assets.write(current_assets + assets);
            
            let shares = assets; // 1:1 for simplicity in mock
            let current_shares = self.vault_shares.read();
            self.vault_shares.write(current_shares + shares);
            
            shares
        }
        
        fn withdraw(ref self: ContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256 {
            let current_assets = self.vault_assets.read();
            assert!(current_assets >= assets, "Insufficient mock assets");
            
            self.vault_assets.write(current_assets - assets);
            
            let shares_to_burn = assets;
            let current_shares = self.vault_shares.read();
            self.vault_shares.write(current_shares - shares_to_burn);
            
            shares_to_burn
        }
        
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.vault_shares.read()
        }
        
        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            // Simulate yield by increasing conversion ratio
            let ratio = self.asset_to_share_ratio.read();
            (shares * ratio) / 1000000
        }
        
        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            let ratio = self.asset_to_share_ratio.read();
            (assets * 1000000) / ratio
        }
        
        fn max_withdraw(self: @ContractState, owner: ContractAddress) -> u256 {
            self.vault_assets.read()
        }
        
        fn max_redeem(self: @ContractState, owner: ContractAddress) -> u256 {
            self.vault_shares.read()
        }
        
        fn simulate_yield(ref self: ContractState, yield_percentage: u256) {
            // Increase asset-to-share ratio to simulate yield
            // yield_percentage is in basis points (100 = 1%)
            let current_ratio = self.asset_to_share_ratio.read();
            let new_ratio = current_ratio + (current_ratio * yield_percentage) / 10000;
            self.asset_to_share_ratio.write(new_ratio);
        }
    }
}
