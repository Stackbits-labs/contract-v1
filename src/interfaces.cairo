// Interface definitions
use starknet::ContractAddress;

// Vault interface definitions
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