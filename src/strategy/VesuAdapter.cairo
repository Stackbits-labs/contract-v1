use starknet::{ContractAddress, get_caller_address, get_contract_address};
use super::super::interfaces::IVesu::{IVesuDispatcher, IVesuDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait, vesu_constants};

// VesuAdapter: Strategy for integrating with Vesu Protocol
#[derive(Copy, Drop, Clone, PartialEq)]
pub struct VesuAdapterConfig {
    pub vesu_protocol: ContractAddress,
    pub asset_token: ContractAddress,      // wBTC address
    pub vtoken_address: ContractAddress,   // wBTC vToken address
    pub vault_address: ContractAddress,    // Our vault address
    pub owner: ContractAddress,            // Strategy owner
    pub is_active: bool,                   // Strategy activation status
}

pub fn get_default_vesu_config() -> VesuAdapterConfig {
    VesuAdapterConfig {
        vesu_protocol: starknet::contract_address_const::<0x1>(), // TODO: Replace with real Vesu address
        asset_token: starknet::contract_address_const::<0x2>(),   // TODO: Replace with wBTC address
        vtoken_address: starknet::contract_address_const::<0x3>(), // TODO: Replace with wBTC vToken
        vault_address: starknet::contract_address_const::<0x4>(),
        owner: starknet::contract_address_const::<0x5>(),
        is_active: true,
    }
}

// Safe approve implementation - critical for DeFi integrations
pub fn safe_approve_erc20(token: ContractAddress, spender: ContractAddress, amount: u256) -> bool {
    let erc20 = IERC20Dispatcher { contract_address: token };
    
    // Step 1: Set allowance to 0 first (prevents race condition attacks)
    let success_reset = erc20.approve(spender, 0);
    if !success_reset {
        return false;
    }
    
    // Step 2: Set the actual amount
    let success_approve = erc20.approve(spender, amount);
    success_approve
}

// VesuAdapter Core Functions
pub fn push_to_vesu(config: VesuAdapterConfig, assets: u256) -> Result<u256, felt252> {
    // Validate inputs
    if assets == 0 {
        return Err('Zero assets to push');
    }
    if !config.is_active {
        return Err('Strategy is inactive');
    }

    let vesu = IVesuDispatcher { contract_address: config.vesu_protocol };
    let asset_token = IERC20Dispatcher { contract_address: config.asset_token };
    
    // Check vault has sufficient balance
    let vault_balance = asset_token.balance_of(config.vault_address);
    if vault_balance < assets {
        return Err('Insufficient vault balance');
    }

    // Safe approve: First set to 0, then set amount
    let approve_success = safe_approve_erc20(
        config.asset_token, 
        config.vesu_protocol, 
        assets
    );
    if !approve_success {
        return Err('Approval failed');
    }

    // Supply assets to Vesu protocol
    let vtokens_received = vesu.supply(config.asset_token, assets);
    
    if vtokens_received == 0 {
        return Err('No vTokens received');
    }

    Ok(vtokens_received)
}

pub fn pull_from_vesu(config: VesuAdapterConfig, assets: u256) -> Result<u256, felt252> {
    // Validate inputs
    if assets == 0 {
        return Err('Zero assets to pull');
    }
    if !config.is_active {
        return Err('Strategy is inactive');
    }

    let vesu = IVesuDispatcher { contract_address: config.vesu_protocol };
    
    // Check if we have enough assets deposited in Vesu
    let available_assets = vesu_assets(config);
    if available_assets < assets {
        return Err('Insufficient Vesu assets');
    }

    // Redeem assets from Vesu
    let assets_received = vesu.redeem(config.asset_token, assets);
    
    if assets_received == 0 {
        return Err('No assets received');
    }

    Ok(assets_received)
}

pub fn vesu_assets(config: VesuAdapterConfig) -> u256 {
    // Get current vToken balance and convert to underlying assets
    let vesu = IVesuDispatcher { contract_address: config.vesu_protocol };
    
    // Get vToken balance of our vault
    let vtoken_balance = vesu.balance_of_vtoken(config.asset_token, config.vault_address);
    
    if vtoken_balance == 0 {
        return 0;
    }
    
    // Get exchange rate (vToken -> asset)
    let exchange_rate = vesu.get_exchange_rate(config.asset_token);
    
    if exchange_rate == 0 {
        return 0; // Avoid division by zero
    }
    
    // Calculate underlying assets: vtoken_balance * exchange_rate / 1e18
    let underlying_assets = (vtoken_balance * exchange_rate) / vesu_constants::EXCHANGE_RATE_DECIMALS;
    underlying_assets
}

// Emergency functions
pub fn emergency_withdraw_all(config: VesuAdapterConfig) -> Result<u256, felt252> {
    if !config.is_active {
        return Err('Strategy is inactive');
    }

    let vesu = IVesuDispatcher { contract_address: config.vesu_protocol };
    let vtoken_balance = vesu.balance_of_vtoken(config.asset_token, config.vault_address);
    
    if vtoken_balance == 0 {
        return Ok(0);
    }

    // Calculate max assets we can withdraw
    let max_assets = vesu_assets(config);
    
    if max_assets == 0 {
        return Ok(0);
    }

    // Withdraw all available assets
    let assets_received = vesu.redeem(config.asset_token, max_assets);
    Ok(assets_received)
}

// View functions for monitoring
pub fn get_vesu_apy(config: VesuAdapterConfig) -> u256 {
    // TODO: Implement APY calculation based on Vesu protocol data
    // This would typically involve reading supply rates from Vesu
    0 // Placeholder
}

pub fn get_health_factor(config: VesuAdapterConfig) -> u256 {
    // TODO: If Vesu uses health factors for borrowing, implement here
    // For supply-only strategy, this might not be needed
    1000000000000000000 // 1.0 in 18 decimals (healthy)
}

// Validation helpers
pub fn is_strategy_healthy(config: VesuAdapterConfig) -> bool {
    // Basic health checks
    if !config.is_active {
        return false;
    }
    
    let vesu_balance = vesu_assets(config);
    // Strategy is healthy if we can read balances (no reverts)
    true
}

pub fn get_strategy_info(config: VesuAdapterConfig) -> (u256, u256, bool) {
    let vesu_balance = vesu_assets(config);
    let apy = get_vesu_apy(config);
    let is_healthy = is_strategy_healthy(config);
    
    (vesu_balance, apy, is_healthy)
}