use stackbits_vault::vault_swbtc::{
    calculate_shares_for_assets,
    calculate_assets_for_shares,
    simulate_deposit,
    simulate_withdraw,
    check_reentrancy,
    get_default_vault_config,
    ReentrancyState
};
use starknet::ContractAddress;
use core::num::traits::Zero;

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner = starknet::contract_address_const::<0x123>();
    let alice = starknet::contract_address_const::<0x456>();
    let bob = starknet::contract_address_const::<0x789>();
    let vault_addr = starknet::contract_address_const::<0xabc>();
    (owner, alice, bob, vault_addr)
}

#[test]
fn test_vault_config() {
    let config = get_default_vault_config();
    
    assert(!config.asset_token.is_zero(), 'Asset token should be set');
    assert(!config.share_token.is_zero(), 'Share token should be set');
    assert(!config.owner.is_zero(), 'Owner should be set');
}

#[test]
fn test_conversion_functions_empty_vault() {
    // When totalSupply == 0, should return 1:1 ratio
    let shares = calculate_shares_for_assets(1000, 0, 0);
    let assets = calculate_assets_for_shares(1000, 0, 0);
    
    assert(shares == 1000, 'Wrong shares conversion');
    assert(assets == 1000, 'Wrong assets conversion');
}

#[test]
fn test_conversion_with_existing_supply() {
    // Test conversion with existing supply and assets
    // 1000 shares, 1500 total assets
    let total_supply = 1000;
    let total_assets = 1500;
    
    // Deposit 750 assets -> should get 500 shares (750 * 1000 / 1500)
    let shares = calculate_shares_for_assets(750, total_supply, total_assets);
    assert(shares == 500, 'Wrong shares calculation');
    
    // Redeem 500 shares -> should get 750 assets (500 * 1500 / 1000)
    let assets = calculate_assets_for_shares(500, total_supply, total_assets);
    assert(assets == 750, 'Wrong assets calculation');
}

#[test]
fn test_rounding_scenarios() {
    // Test rounding with small amounts
    let total_supply = 3;
    let total_assets = 5;
    
    // Deposit 7 assets -> shares = 7 * 3 / 5 = 21/5 = 4 (floor)
    let shares = calculate_shares_for_assets(7, total_supply, total_assets);
    assert(shares == 4, 'Wrong rounding for shares');
    
    // Redeem 2 shares -> assets = 2 * 5 / 3 = 10/3 = 3 (floor)
    let assets = calculate_assets_for_shares(2, total_supply, total_assets);
    assert(assets == 3, 'Wrong rounding for assets');
}

#[test]
fn test_zero_total_assets_edge_case() {
    // When total_assets = 0 but total_supply > 0
    let shares = calculate_shares_for_assets(100, 1000, 0);
    assert(shares == 0, 'Zero shares for zero assets');
}

#[test]
fn test_deposit_simulation() {
    let (_, alice, _, _) = get_test_addresses();
    
    let (shares, event) = simulate_deposit(1000, alice, 0, 0);
    
    assert(shares == 1000, 'Wrong shares from deposit');
    assert(event.user == alice, 'Wrong user in event');
    assert(event.receiver == alice, 'Wrong receiver in event');
    assert(event.assets == 1000, 'Wrong assets in event');
    assert(event.shares == 1000, 'Wrong shares in event');
}

#[test]
fn test_withdraw_simulation() {
    let (_, alice, _, _) = get_test_addresses();
    
    let (shares, event) = simulate_withdraw(750, alice, alice, 1000, 1500);
    
    assert(shares == 500, 'Wrong shares from withdraw');
    assert(event.user == alice, 'Wrong user in event');
    assert(event.receiver == alice, 'Wrong receiver in event');
    assert(event.owner == alice, 'Wrong owner in event');
    assert(event.assets == 750, 'Wrong assets in event');
    assert(event.shares == 500, 'Wrong shares in event');
}

#[test]
fn test_reentrancy_guard() {
    let not_entered = ReentrancyState { entered: false };
    let entered = ReentrancyState { entered: true };
    
    assert(check_reentrancy(not_entered) == true, 'Should allow when not entered');
    assert(check_reentrancy(entered) == false, 'Should block when entered');
}

#[test]
fn test_deposit_withdraw_round_trip() {
    let (_, alice, _, _) = get_test_addresses();
    
    // Simulate initial deposit: 1000 assets -> 1000 shares (1:1 ratio)
    let (deposit_shares, _) = simulate_deposit(1000, alice, 0, 0);
    assert(deposit_shares == 1000, 'Wrong initial deposit');
    
    // Now simulate: total_supply = 1000, total_assets = 1000
    // Withdraw all: 1000 shares -> 1000 assets
    let withdraw_assets = calculate_assets_for_shares(1000, 1000, 1000);
    assert(withdraw_assets == 1000, 'Should get back same amount');
}

#[test]
fn test_multiple_users_scenario() {
    let (_, alice, bob, _) = get_test_addresses();
    
    // Alice deposits 1000 (first user, gets 1000 shares)
    let (alice_shares, _) = simulate_deposit(1000, alice, 0, 0);
    assert(alice_shares == 1000, 'Wrong Alice shares');
    
    // Vault gains 500 in value (now 1500 assets, 1000 shares)
    // Bob deposits 1500 -> should get 1000 shares (1500 * 1000 / 1500)
    let bob_shares = calculate_shares_for_assets(1500, 1000, 1500);
    assert(bob_shares == 1000, 'Wrong Bob shares');
    
    // Now vault has 3000 assets, 2000 shares
    // Alice redeems 500 shares -> gets 750 assets (500 * 3000 / 2000)
    let alice_withdrawal = calculate_assets_for_shares(500, 2000, 3000);
    assert(alice_withdrawal == 750, 'Wrong Alice withdrawal');
}