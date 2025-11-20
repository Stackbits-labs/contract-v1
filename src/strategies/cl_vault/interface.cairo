use starknet::{ContractAddress};
use stackbits_contract_v1::interfaces::IEkuboCore::{Bounds, PoolKey, PositionKey};
use ekubo::types::position::Position;
use stackbits_contract_v1::components::swap::{AvnuMultiRouteSwap};

// Types definition (no need for separate types.cairo since we don't use interface.cairo)
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ClSettings {
    pub ekubo_positions_contract: ContractAddress,
    pub bounds_settings: Bounds,
    pub pool_key: PoolKey,
    pub ekubo_positions_nft: ContractAddress,
    pub contract_nft_id: u64, // NFT position id of Ekubo position
    pub ekubo_core: ContractAddress,
    pub oracle: ContractAddress,
    pub fee_settings: FeeSettings,
}

#[derive(Drop, Copy, Serde)]
pub struct MyPosition {
    pub liquidity: u256,
    pub amount0: u256,
    pub amount1: u256,
}

#[derive(Drop, Copy, Serde, starknet::Store, starknet::Event)]
pub struct FeeSettings {
    pub fee_bps: u256,
    pub fee_collector: ContractAddress
}

/// CL Vault interface without harvest function
/// For stablecoin pools, harvest is not needed (STRK rewards are minimal)
/// Only includes functions used by StablecoinAutoCLVault:
/// - deposit, withdraw, handle_fees, rebalance, handle_unused
#[starknet::interface]
pub trait IClVault<TContractState> {
    /// Deposit tokens into CL vault
    fn deposit(
        ref self: TContractState, amount0: u256, amount1: u256, receiver: ContractAddress
    ) -> u256;
    
    /// Withdraw tokens from CL vault
    fn withdraw(ref self: TContractState, shares: u256, receiver: ContractAddress) -> MyPosition;
    
    /// Convert token amounts to shares
    fn convert_to_shares(self: @TContractState, amount0: u256, amount1: u256) -> u256;
    
    /// Convert shares to token amounts
    fn convert_to_assets(self: @TContractState, shares: u256) -> MyPosition;
    
    /// Get total liquidity in vault
    fn total_liquidity(self: @TContractState) -> u256;
    
    /// Get position key
    fn get_position_key(self: @TContractState) -> PositionKey;
    
    /// Get position details
    fn get_position(self: @TContractState) -> Position;
    
    /// Handle fees (collect and reinvest)
    fn handle_fees(ref self: TContractState);
    
    /// Get vault settings
    fn get_settings(self: @TContractState) -> ClSettings;
    
    /// Handle unused tokens (swap to balance)
    fn handle_unused(ref self: TContractState, swap_params: AvnuMultiRouteSwap);
    
    /// Rebalance to new price bounds
    fn rebalance(ref self: TContractState, new_bounds: Bounds, swap_params: AvnuMultiRouteSwap);
    
    /// Set fee settings
    fn set_settings(ref self: TContractState, fee_settings: FeeSettings);
    
    /// Disable incentives (if needed)
    fn set_incentives_off(ref self: TContractState);
    
    // NOTE: harvest() function removed - not needed for stablecoin pools
    // Harvester is not needed for stablecoin/stablecoin pools (STRK rewards are minimal)
}

