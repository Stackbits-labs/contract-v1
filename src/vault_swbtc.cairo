// VaultSwBTC - Enhanced vault implementation with automatic Vesu strategy integration
use starknet::ContractAddress;
use super::interfaces::{Deposit, Withdraw, Invest, Divest, Rebalance};
use super::strategy::VesuAdapter::{
    VesuAdapterConfig, vesu_assets, get_default_vesu_config, 
    push_to_vesu, pull_from_vesu, is_strategy_healthy
};

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

// Enhanced totalAssets function that includes Vesu strategy
pub fn total_assets_with_strategy(
    vault_balance: u256,
    vesu_config: VesuAdapterConfig
) -> u256 {
    // Calculate total assets = vault balance + assets deployed in Vesu
    let vesu_deployed_assets = vesu_assets(vesu_config);
    vault_balance + vesu_deployed_assets
}

// Vault management with strategy integration
pub fn can_withdraw_from_vault(
    requested_assets: u256,
    vault_balance: u256,
    vesu_config: VesuAdapterConfig
) -> bool {
    let total_available = total_assets_with_strategy(vault_balance, vesu_config);
    total_available >= requested_assets
}

pub fn calculate_withdrawal_sources(
    requested_assets: u256,
    vault_balance: u256,
    vesu_config: VesuAdapterConfig
) -> (u256, u256) {
    // Returns (from_vault, from_vesu)
    if vault_balance >= requested_assets {
        (requested_assets, 0)
    } else {
        let from_vault = vault_balance;
        let from_vesu = requested_assets - vault_balance;
        (from_vault, from_vesu)
    }
}

// Enhanced Vault Configuration with Strategy
#[derive(Copy, Drop)]
pub struct EnhancedVaultConfig {
    pub asset_token: ContractAddress,
    pub share_token: ContractAddress,
    pub owner: ContractAddress,
    pub vesu_config: VesuAdapterConfig,
    pub target_idle_bps: u256,  // Target idle percentage in basis points (e.g., 1000 = 10%)
    pub auto_invest_enabled: bool,
    pub min_investment_amount: u256,
}

// Enhanced deposit function with auto-invest
pub fn enhanced_deposit(
    assets: u256,
    receiver: ContractAddress,
    vault_balance: u256,
    total_supply: u256,
    total_assets: u256,
    config: EnhancedVaultConfig
) -> Result<(u256, Deposit, Option<Invest>), felt252> {
    // Input validation
    if assets == 0 {
        return Err('Zero assets to deposit');
    }
    
    // Calculate shares to mint
    let shares = calculate_shares_for_assets(assets, total_supply, total_assets);
    
    // Create deposit event
    let deposit_event = Deposit {
        user: receiver,
        receiver,
        assets,
        shares,
    };
    
    // Auto-invest logic: check if we should invest in Vesu
    let mut invest_event: Option<Invest> = Option::None;
    
    if config.auto_invest_enabled && assets >= config.min_investment_amount {
        // Check if strategy is healthy
        if is_strategy_healthy(config.vesu_config) {
            // Calculate how much to invest (leave some idle for withdrawals)
            let new_vault_balance = vault_balance + assets;
            let target_idle = (new_vault_balance * config.target_idle_bps) / 10000;
            
            if new_vault_balance > target_idle {
                let amount_to_invest = new_vault_balance - target_idle;
                
                if amount_to_invest > 0 {
                    // Would call push_to_vesu in real implementation
                    invest_event = Option::Some(Invest {
                        vault: config.owner, // Using owner as vault identifier
                        assets: amount_to_invest,
                        timestamp: 0, // Would use starknet::get_block_timestamp() in real contract
                    });
                }
            }
        }
    }
    
    Result::Ok((shares, deposit_event, invest_event))
}

// Enhanced withdraw function with auto-divest
pub fn enhanced_withdraw(
    assets: u256,
    receiver: ContractAddress,
    owner: ContractAddress,
    vault_balance: u256,
    total_supply: u256,
    total_assets: u256,
    config: EnhancedVaultConfig
) -> Result<(u256, Withdraw, Option<Divest>), felt252> {
    // Input validation
    if assets == 0 {
        return Err('Zero assets to withdraw');
    }
    
    // Check if we have enough total assets
    let total_available = total_assets_with_strategy(vault_balance, config.vesu_config);
    if total_available < assets {
        return Err('Insufficient total assets');
    }
    
    // Calculate shares to burn
    let shares = calculate_shares_for_assets(assets, total_supply, total_assets);
    
    // Create withdraw event
    let withdraw_event = Withdraw {
        user: owner,
        receiver,
        owner,
        assets,
        shares,
    };
    
    // Auto-divest logic: check if we need to pull from Vesu
    let mut divest_event: Option<Divest> = Option::None;
    
    if vault_balance < assets {
        let amount_to_divest = assets - vault_balance;
        
        // Check if strategy is healthy for divestment
        if is_strategy_healthy(config.vesu_config) {
            // Would call pull_from_vesu in real implementation
            divest_event = Option::Some(Divest {
                vault: config.owner,
                assets: amount_to_divest,
                timestamp: 0,
            });
        } else {
            return Err('Strategy unhealthy');
        }
    }
    
    Result::Ok((shares, withdraw_event, divest_event))
}

// Rebalance function to manage idle vs invested ratio
pub fn rebalance_idle(
    current_vault_balance: u256,
    target_idle_bps: u256,
    config: EnhancedVaultConfig
) -> Result<(Option<Invest>, Option<Divest>, Rebalance), felt252> {
    // Calculate total assets across vault and Vesu
    let total_assets = total_assets_with_strategy(current_vault_balance, config.vesu_config);
    
    if total_assets == 0 {
        return Err('No assets to rebalance');
    }
    
    // Calculate target idle amount
    let target_idle = (total_assets * target_idle_bps) / 10000;
    let current_idle = current_vault_balance;
    
    let mut invest_event: Option<Invest> = Option::None;
    let mut divest_event: Option<Divest> = Option::None;
    
    // Check if strategy is healthy
    if !is_strategy_healthy(config.vesu_config) {
        return Err('Strategy is unhealthy');
    }
    
    if current_idle > target_idle {
        // Too much idle, invest excess
        let amount_to_invest = current_idle - target_idle;
        if amount_to_invest >= config.min_investment_amount {
            invest_event = Option::Some(Invest {
                vault: config.owner,
                assets: amount_to_invest,
                timestamp: 0,
            });
        }
    } else if current_idle < target_idle {
        // Too little idle, divest from Vesu
        let amount_to_divest = target_idle - current_idle;
        let vesu_assets = vesu_assets(config.vesu_config);
        
        if vesu_assets >= amount_to_divest {
            divest_event = Option::Some(Divest {
                vault: config.owner,
                assets: amount_to_divest,
                timestamp: 0,
            });
        } else {
            return Err('Insufficient Vesu assets');
        }
    }
    
    let rebalance_event = Rebalance {
        vault: config.owner,
        idle_before: current_idle,
        idle_after: target_idle,
        target_idle_bps,
    };
    
    Result::Ok((invest_event, divest_event, rebalance_event))
}

// Helper function to create enhanced config
pub fn get_enhanced_vault_config() -> EnhancedVaultConfig {
    EnhancedVaultConfig {
        asset_token: starknet::contract_address_const::<0x1>(),
        share_token: starknet::contract_address_const::<0x2>(),
        owner: starknet::contract_address_const::<0x3>(),
        vesu_config: get_default_vesu_config(),
        target_idle_bps: 1000, // 10% idle by default
        auto_invest_enabled: true,
        min_investment_amount: 1000000, // 1 wBTC minimum
    }
}

// Vault state management
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct VaultState {
    pub total_supply: u256,
    pub vault_balance: u256,
    pub last_rebalance: u64,
    pub total_invested: u256,
    pub total_divested: u256,
}

// Calculate current APY based on strategy performance
pub fn calculate_vault_apy(
    initial_assets: u256,
    current_assets: u256,
    time_elapsed: u64
) -> u256 {
    if initial_assets == 0 || time_elapsed == 0 {
        return 0;
    }
    
    // Simple APY calculation: ((current/initial) - 1) * (365 * 24 * 3600) / time_elapsed * 100
    // For demonstration, returning a simple percentage
    if current_assets > initial_assets {
        let gain = current_assets - initial_assets;
        (gain * 10000) / initial_assets // Return in basis points
    } else {
        0
    }
}