// SNIP-22 (ERC-4626-like) Vault Interface Definitions
use starknet::ContractAddress;

// Include Vesu Protocol interfaces
pub mod IVesu;

// SNIP-22 Vault Events
#[derive(Drop, starknet::Event)]
pub struct Deposit {
    #[key]
    pub user: ContractAddress,
    #[key] 
    pub receiver: ContractAddress,
    pub assets: u256,
    pub shares: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Withdraw {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub receiver: ContractAddress, 
    #[key]
    pub owner: ContractAddress,
    pub assets: u256,
    pub shares: u256,
}

// SNIP-22 Vault Interface (ERC-4626 compatible)
#[starknet::interface]
pub trait ISnip22Vault<TContractState> {
    // ===== VIEW FUNCTIONS =====
    
    // Core vault state
    fn total_assets(self: @TContractState) -> u256;
    
    // Conversion functions
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    
    // Preview functions for exact amounts
    fn preview_deposit(self: @TContractState, assets: u256) -> u256;
    fn preview_mint(self: @TContractState, shares: u256) -> u256;
    fn preview_withdraw(self: @TContractState, assets: u256) -> u256;
    fn preview_redeem(self: @TContractState, shares: u256) -> u256;
    
    // Maximum operation limits (optional but recommended)
    fn max_deposit(self: @TContractState, receiver: ContractAddress) -> u256;
    fn max_mint(self: @TContractState, receiver: ContractAddress) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    fn max_redeem(self: @TContractState, owner: ContractAddress) -> u256;
    
    // ===== EXTERNAL FUNCTIONS =====
    
    // Deposit assets and receive shares
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    
    // Mint specific amount of shares
    fn mint(ref self: TContractState, shares: u256, receiver: ContractAddress) -> u256;
    
    // Withdraw specific amount of assets
    fn withdraw(
        ref self: TContractState, 
        assets: u256, 
        receiver: ContractAddress, 
        owner: ContractAddress
    ) -> u256;
    
    // Redeem specific amount of shares for assets
    fn redeem(
        ref self: TContractState, 
        shares: u256, 
        receiver: ContractAddress, 
        owner: ContractAddress
    ) -> u256;
}

// Legacy vault interface for backwards compatibility
#[starknet::interface]
pub trait IVault<TContractState> {
    fn deposit(ref self: TContractState, amount: u256) -> u256;
    fn withdraw(ref self: TContractState, shares: u256) -> u256;
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

// Strategy interface definitions
#[starknet::interface]
pub trait IStrategy<TContractState> {
    fn invest(ref self: TContractState, amount: u256) -> bool;
    fn divest(ref self: TContractState, amount: u256) -> u256;
    fn get_invested_amount(self: @TContractState) -> u256;
    fn get_manager(self: @TContractState) -> ContractAddress;
}