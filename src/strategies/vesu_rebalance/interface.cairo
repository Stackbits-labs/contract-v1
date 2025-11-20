use starknet::{ContractAddress};

// Types definition (no need for separate types.cairo since we don't use interface.cairo)
#[derive(PartialEq, Copy, Drop, Serde, Default)]
pub enum Feature {
    #[default]
    DEPOSIT,
    WITHDRAW
}

#[derive(PartialEq, Drop, Copy, Serde)]
pub struct Action {
    pub pool_id: felt252,
    pub feature: Feature,
    // should be asset() when borrowing not enabled
    pub token: ContractAddress,
    pub amount: u256
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PoolProps {
    pub pool_id: felt252, // vesu pool id
    pub max_weight: u32, // in bps relative to total_assets
    pub v_token: ContractAddress,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
// vault general settings
pub struct Settings {
    pub default_pool_index: u8,
    pub fee_bps: u32,
    pub fee_receiver: ContractAddress,
}

/// Vesu Rebalance interface without harvest function
/// For stablecoin pools, harvest is not needed (STRK rewards are minimal)
/// Only includes functions used by StablecoinAutoCLVault:
/// - rebalance, compute_yield, get_settings, get_allowed_pools
#[starknet::interface]
pub trait IVesuRebal<TContractState> {
    /// Rebalance assets between pools
    fn rebalance(ref self: TContractState, actions: Array<Action>);
    
    /// Rebalance weights between pools
    fn rebalance_weights(ref self: TContractState, actions: Array<Action>);
    
    /// Emergency withdraw all assets
    fn emergency_withdraw(ref self: TContractState);
    
    /// Emergency withdraw from specific pool
    fn emergency_withdraw_pool(ref self: TContractState, pool_index: u32);
    
    /// Compute yield (current and previous)
    fn compute_yield(self: @TContractState) -> (u256, u256);
    
    // Setters
    /// Set vault settings
    fn set_settings(ref self: TContractState, settings: Settings);
    
    /// Set allowed pools
    fn set_allowed_pools(ref self: TContractState, pools: Array<PoolProps>);
    
    /// Disable incentives (if needed)
    fn set_incentives_off(ref self: TContractState);
    
    // Getters
    /// Get vault settings
    fn get_settings(self: @TContractState) -> Settings;
    
    /// Get allowed pools
    fn get_allowed_pools(self: @TContractState) -> Array<PoolProps>;
    
    /// Get previous index
    fn get_previous_index(self: @TContractState) -> u128;
    
    // NOTE: harvest() function removed - not needed for stablecoin pools
    // Harvester is not needed for stablecoin/stablecoin pools (STRK rewards are minimal)
}

/// Interface for migrating from V1 to V2 vTokens
#[starknet::interface]
pub trait IVesuMigrate<TContractState> {
    fn vesu_migrate(
        ref self: TContractState,
        new_singleton: ContractAddress,
        new_pool_tokens: Array<ContractAddress>,
    );
}

/// Dispatcher for V2 vToken contract
#[starknet::interface]
pub trait IVesuTokenV2<TContractState> {
    fn migrate_v_token(ref self: TContractState);
    fn v_token_v1(self: @TContractState) -> ContractAddress;
}
