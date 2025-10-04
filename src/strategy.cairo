// Base strategy implementation
use starknet::ContractAddress;

/// Strategy information struct
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct StrategyInfo {
    pub name: felt252,
    pub manager: ContractAddress,
    pub active: bool,
}

/// Get default strategy info
pub fn get_default_strategy() -> StrategyInfo {
    StrategyInfo {
        name: 'default_strategy',
        manager: starknet::contract_address_const::<0>(),
        active: false
    }
}