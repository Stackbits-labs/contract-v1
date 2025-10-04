// VaultSwBTC - Simplified vault implementation for demonstration
use starknet::ContractAddress;
use super::interfaces::{Deposit, Withdraw};

// Vault configuration struct
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct VaultConfig {
    pub asset_token: ContractAddress,
    pub share_token: ContractAddress,
    pub owner: ContractAddress,
}

// Vault operations for testing
pub fn calculate_shares_for_assets(assets: u256, total_supply: u256, total_assets: u256) -> u256 {
    if total_supply == 0 {
        assets // 1:1 ratio when no shares exist
    } else {
        if total_assets == 0 {
            0
        } else {
            // shares = floor(assets * totalSupply / totalAssets)
            (assets * total_supply) / total_assets
        }
    }
}

pub fn calculate_assets_for_shares(shares: u256, total_supply: u256, total_assets: u256) -> u256 {
    if total_supply == 0 {
        shares // 1:1 ratio when no shares exist
    } else {
        // assets = floor(shares * totalAssets / totalSupply)
        (shares * total_assets) / total_supply
    }
}

// Reentrancy guard state
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ReentrancyState {
    pub entered: bool,
}

pub fn check_reentrancy(state: ReentrancyState) -> bool {
    !state.entered
}

pub fn get_default_vault_config() -> VaultConfig {
    VaultConfig {
        asset_token: starknet::contract_address_const::<0x1>(),
        share_token: starknet::contract_address_const::<0x2>(),
        owner: starknet::contract_address_const::<0x3>(),
    }
}

// Vault operation simulation
pub fn simulate_deposit(
    assets: u256,
    receiver: ContractAddress,
    total_supply: u256,
    total_assets: u256
) -> (u256, Deposit) {
    let shares = calculate_shares_for_assets(assets, total_supply, total_assets);
    let event = Deposit {
        user: receiver, // Simplified for testing
        receiver,
        assets,
        shares,
    };
    (shares, event)
}

pub fn simulate_withdraw(
    assets: u256,
    receiver: ContractAddress,
    owner: ContractAddress,
    total_supply: u256,
    total_assets: u256
) -> (u256, Withdraw) {
    let shares = calculate_shares_for_assets(assets, total_supply, total_assets);
    let event = Withdraw {
        user: owner, // Simplified for testing
        receiver,
        owner,
        assets,
        shares,
    };
    (shares, event)
}