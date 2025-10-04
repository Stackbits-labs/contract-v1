// swBTC Token - ERC-20 Share Token for Vault System
use starknet::ContractAddress;

// ERC-20 Events
#[derive(Drop, starknet::Event)]
pub struct Transfer {
    #[key]
    pub from: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub value: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Approval {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub spender: ContractAddress,
    pub value: u256,
}

// Role-based Events
#[derive(Drop, starknet::Event)]
pub struct VaultSet {
    #[key]
    pub old_vault: ContractAddress,
    #[key]
    pub new_vault: ContractAddress,
}

// ERC-20 Interface
#[starknet::interface]
pub trait ISwBTC<TContractState> {
    // ===== ERC-20 Standard Functions =====
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    
    fn transfer(ref self: TContractState, to: ContractAddress, value: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, 
        from: ContractAddress, 
        to: ContractAddress, 
        value: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, value: u256) -> bool;
    
    // ===== Vault-Only Functions =====
    fn mint(ref self: TContractState, to: ContractAddress, value: u256);
    fn burn(ref self: TContractState, from: ContractAddress, value: u256);
    
    // ===== Access Control =====
    fn vault(self: @TContractState) -> ContractAddress;
    fn set_vault(ref self: TContractState, new_vault: ContractAddress);
    
    // ===== Optional Permit Support =====
    fn nonces(self: @TContractState, owner: ContractAddress) -> u256;
}

// Simplified swBTC Token Implementation for testing
pub fn get_token_name() -> ByteArray {
    "Staked Wrapped BTC"
}

pub fn get_token_symbol() -> ByteArray {
    "swBTC"
}

pub fn get_token_decimals() -> u8 {
    18
}

// Basic token state for testing
#[derive(Drop, Serde, starknet::Store)]
pub struct TokenInfo {
    pub decimals: u8,
    pub total_supply: u256,
}

pub fn get_default_token_info() -> TokenInfo {
    TokenInfo {
        decimals: get_token_decimals(),
        total_supply: 0,
    }
}

// Role-based access control helper
pub fn is_vault_authorized(vault_address: ContractAddress, caller: ContractAddress) -> bool {
    vault_address == caller
}