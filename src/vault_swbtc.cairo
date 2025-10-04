// VaultSwBTC - Enhanced vault implementation with automatic Vesu strategy integration and fee management
use starknet::ContractAddress;
use super::interfaces::{Deposit, Withdraw, Invest, Divest, Rebalance, FeesCharged, HarvestExecuted, KeeperUpdated};
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

// Fee Management State
#[derive(Copy, Drop)]
pub struct FeeConfig {
    pub treasury: ContractAddress,
    pub management_fee_bps: u256,    // Management fee in basis points (e.g., 200 = 2% annual)
    pub performance_fee_bps: u256,   // Performance fee in basis points (e.g., 2000 = 20%)
    pub last_fee_timestamp: u64,     // Last time fees were charged
    pub high_water_mark: u256,       // High water mark for performance fees
}

// Keeper Role Management
#[derive(Copy, Drop)]
pub struct KeeperConfig {
    pub keeper: ContractAddress,
    pub authorized: bool,
}

// Fee Preview Structure
#[derive(Copy, Drop)]
pub struct FeePreview {
    pub management_fee_shares: u256,
    pub performance_fee_shares: u256,
    pub total_fee_shares: u256,
    pub projected_profit: u256,
    pub time_since_last_harvest: u64,
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

// ===== FEE MANAGEMENT FUNCTIONS =====

// Constants for fee calculations
pub mod fee_constants {
    pub const SECONDS_PER_YEAR: u64 = 31536000; // 365 * 24 * 3600
    pub const BASIS_POINTS_SCALE: u256 = 10000; // 1 = 0.01%
    pub const MAX_MANAGEMENT_FEE: u256 = 500; // 5% max management fee
    pub const MAX_PERFORMANCE_FEE: u256 = 5000; // 50% max performance fee
}

// Preview fees without executing harvest
pub fn preview_fees(
    vault_balance: u256,
    vesu_config: VesuAdapterConfig,
    fee_config: FeeConfig,
    total_supply: u256,
    current_timestamp: u64
) -> FeePreview {
    // Calculate gross assets (vault + strategy)
    let gross_assets = total_assets_with_strategy(vault_balance, vesu_config);
    
    // Calculate performance fees
    let (performance_fee_shares, profit) = if gross_assets > fee_config.high_water_mark {
        let profit = gross_assets - fee_config.high_water_mark;
        let perf_fee_assets = (profit * fee_config.performance_fee_bps) / fee_constants::BASIS_POINTS_SCALE;
        
        // Convert fee assets to shares
        let perf_fee_shares = if total_supply == 0 {
            perf_fee_assets
        } else {
            (perf_fee_assets * total_supply) / gross_assets
        };
        (perf_fee_shares, profit)
    } else {
        (0, 0)
    };
    
    // Calculate management fees
    let time_elapsed = current_timestamp - fee_config.last_fee_timestamp;
    let management_fee_shares = if time_elapsed > 0 && total_supply > 0 {
        // Annual management fee converted to per-second rate
        let annual_mgmt_fee = (gross_assets * fee_config.management_fee_bps) / fee_constants::BASIS_POINTS_SCALE;
        let mgmt_fee_assets = (annual_mgmt_fee * time_elapsed.into()) / fee_constants::SECONDS_PER_YEAR.into();
        
        // Convert to shares
        (mgmt_fee_assets * total_supply) / gross_assets
    } else {
        0
    };
    
    FeePreview {
        management_fee_shares,
        performance_fee_shares,
        total_fee_shares: management_fee_shares + performance_fee_shares,
        projected_profit: profit,
        time_since_last_harvest: time_elapsed,
    }
}

// Execute harvest - collect fees and update high water mark
pub fn harvest(
    vault_balance: u256,
    vesu_config: VesuAdapterConfig,
    mut fee_config: FeeConfig,
    total_supply: u256,
    current_timestamp: u64,
    caller: ContractAddress,
    keeper_config: KeeperConfig
) -> Result<(FeeConfig, u256, u256, super::interfaces::FeesCharged, super::interfaces::HarvestExecuted), felt252> {
    // Check keeper authorization
    if caller != keeper_config.keeper || !keeper_config.authorized {
        return Err('Unauthorized keeper');
    }
    
    // Calculate gross assets before harvest
    let gross_assets_before = total_assets_with_strategy(vault_balance, vesu_config);
    
    // Preview fees to calculate
    let fee_preview = preview_fees(vault_balance, vesu_config, fee_config, total_supply, current_timestamp);
    
    // Update fee config
    fee_config.last_fee_timestamp = current_timestamp;
    
    // Update high water mark only if we have profit
    let new_high_water_mark = if fee_preview.projected_profit > 0 {
        // HWM updates to total assets after minting fee shares
        let assets_after_fees = gross_assets_before; // Simplified for demonstration
        if assets_after_fees > fee_config.high_water_mark {
            assets_after_fees
        } else {
            fee_config.high_water_mark
        }
    } else {
        fee_config.high_water_mark
    };
    
    fee_config.high_water_mark = new_high_water_mark;
    
    // Create events
    let fees_charged_event = super::interfaces::FeesCharged {
        vault: fee_config.treasury, // Using treasury as vault identifier
        performance_fee_shares: fee_preview.performance_fee_shares,
        management_fee_shares: fee_preview.management_fee_shares,
        total_fee_shares: fee_preview.total_fee_shares,
        high_water_mark: new_high_water_mark,
        timestamp: current_timestamp,
    };
    
    let harvest_event = super::interfaces::HarvestExecuted {
        vault: fee_config.treasury,
        keeper: caller,
        gross_assets_before,
        gross_assets_after: new_high_water_mark, // Approximation
        profit: fee_preview.projected_profit,
        timestamp: current_timestamp,
    };
    
    Result::Ok((
        fee_config,
        fee_preview.management_fee_shares,
        fee_preview.performance_fee_shares,
        fees_charged_event,
        harvest_event
    ))
}

// Validate fee configuration
pub fn validate_fee_config(fee_config: FeeConfig) -> Result<(), felt252> {
    if fee_config.management_fee_bps > fee_constants::MAX_MANAGEMENT_FEE {
        return Err('Management fee too high');
    }
    
    if fee_config.performance_fee_bps > fee_constants::MAX_PERFORMANCE_FEE {
        return Err('Performance fee too high');
    }
    
    Result::Ok(())
}

// Authorize or deauthorize keeper
pub fn update_keeper(
    mut keeper_config: KeeperConfig,
    new_keeper: ContractAddress,
    authorized: bool,
    caller: ContractAddress,
    owner: ContractAddress
) -> Result<(KeeperConfig, super::interfaces::KeeperUpdated), felt252> {
    // Only owner can update keepers
    if caller != owner {
        return Err('Only owner can update keeper');
    }
    
    keeper_config.keeper = new_keeper;
    keeper_config.authorized = authorized;
    
    let event = super::interfaces::KeeperUpdated {
        vault: owner,
        keeper: new_keeper,
        authorized,
    };
    
    Result::Ok((keeper_config, event))
}

// Helper to create default fee config
pub fn get_default_fee_config(treasury: ContractAddress, current_timestamp: u64) -> FeeConfig {
    FeeConfig {
        treasury,
        management_fee_bps: 200, // 2% annual management fee
        performance_fee_bps: 2000, // 20% performance fee
        last_fee_timestamp: current_timestamp,
        high_water_mark: 0, // Start with 0, will be set on first harvest
    }
}

// Helper to create default keeper config
pub fn get_default_keeper_config(keeper: ContractAddress) -> KeeperConfig {
    KeeperConfig {
        keeper,
        authorized: true,
    }
}

// Calculate shares to mint for fees (helper function)
pub fn calculate_fee_shares(
    fee_assets: u256,
    total_assets: u256,
    total_supply: u256
) -> u256 {
    if total_supply == 0 || total_assets == 0 {
        return fee_assets; // 1:1 if no existing shares
    }
    
    // shares = fee_assets * total_supply / total_assets
    (fee_assets * total_supply) / total_assets
}

// Get time-weighted management fee calculation
pub fn calculate_time_weighted_management_fee(
    total_assets: u256,
    management_fee_bps: u256,
    time_elapsed_seconds: u64
) -> u256 {
    if total_assets == 0 || time_elapsed_seconds == 0 {
        return 0;
    }
    
    // Annual fee converted to time-weighted fee
    let annual_fee = (total_assets * management_fee_bps) / fee_constants::BASIS_POINTS_SCALE;
    (annual_fee * time_elapsed_seconds.into()) / fee_constants::SECONDS_PER_YEAR.into()
}