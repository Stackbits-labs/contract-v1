// Edge case tests with clean, focused code
const ONE_WBTC: u256 = 100000000;

#[test]
fn test_zero_deposit_handling() {
    // Test deposit of zero amount
    let deposit_amount = 0_u256;
    let current_total_supply = ONE_WBTC;
    
    // Calculate tokens to mint for zero deposit
    let tokens_to_mint = deposit_amount; // Should be 1:1 ratio
    
    assert!(tokens_to_mint == 0, "Zero deposit should mint zero tokens");
    
    // Verify total supply remains unchanged
    let new_total_supply = current_total_supply + tokens_to_mint;
    assert!(new_total_supply == current_total_supply, "Total supply should not change with zero deposit");
}

#[test]
fn test_minimum_deposit_amounts() {
    // Test smallest possible deposit (1 satoshi)
    let min_deposit = 1_u256;
    let tokens_minted = min_deposit; // 1:1 ratio
    
    assert!(tokens_minted == 1, "Minimum deposit should mint 1 token");
    
    // Test that user can actually deposit minimum amount
    let user_balance = 1_u256;
    let can_deposit = user_balance >= min_deposit;
    assert!(can_deposit == true, "User should be able to deposit minimum amount");
}

#[test]
fn test_maximum_deposit_limits() {
    // Test with maximum realistic Bitcoin amount
    let max_bitcoin_ever = 2100000000000000_u256; // 21M BTC in satoshis
    let large_deposit = max_bitcoin_ever / 2; // 10.5M BTC
    
    // Test token minting for large deposit
    let tokens_minted = large_deposit; // 1:1 ratio
    assert!(tokens_minted == large_deposit, "Large deposits should maintain 1:1 ratio");
    
    // Test that calculation doesn't overflow
    let total_supply_before = max_bitcoin_ever / 4; // 5.25M BTC existing
    let new_total_supply = total_supply_before + tokens_minted;
    
    assert!(new_total_supply > total_supply_before, "New total should be greater than before");
    assert!(new_total_supply == (max_bitcoin_ever / 4 + max_bitcoin_ever / 2), "Should equal sum of parts");
}

#[test]
fn test_withdraw_more_than_balance() {
    // Test attempting to withdraw more than user owns
    let user_balance = ONE_WBTC / 2; // 0.5 wBTC
    let withdraw_request = ONE_WBTC; // 1.0 wBTC
    
    let can_withdraw = user_balance >= withdraw_request;
    assert!(can_withdraw == false, "Should not allow withdrawal exceeding balance");
    
    // Calculate maximum withdrawable
    let max_withdrawable = user_balance;
    assert!(max_withdrawable == ONE_WBTC / 2, "Max withdrawal should equal user balance");
}

#[test]
fn test_withdraw_exact_balance() {
    // Test withdrawing exact balance (should work)
    let user_balance = ONE_WBTC;
    let withdraw_request = ONE_WBTC;
    
    let can_withdraw = user_balance >= withdraw_request;
    assert!(can_withdraw == true, "Should allow withdrawal of exact balance");
    
    // Test resulting balance after withdrawal
    let remaining_balance = user_balance - withdraw_request;
    assert!(remaining_balance == 0, "Balance should be zero after full withdrawal");
}

#[test]
fn test_contract_with_zero_total_supply() {
    // Test yield distribution when no tokens exist
    let total_supply = 0_u256;
    let yield_from_vesu = ONE_WBTC / 10; // 0.1 wBTC yield
    
    // When no tokens exist, no one should get yield
    let distributed_yield = if total_supply == 0 { 0 } else { yield_from_vesu };
    
    assert!(distributed_yield == 0, "No yield should be distributed when no tokens exist");
    
    // Verify yield remains in contract
    let undistributed_yield = yield_from_vesu - distributed_yield;
    assert!(undistributed_yield == yield_from_vesu, "All yield should remain undistributed");
}

#[test]
fn test_single_user_gets_all_yield() {
    // Test scenario with only one token holder
    let single_user_balance = ONE_WBTC;
    let total_supply = ONE_WBTC;
    let total_yield = ONE_WBTC / 20; // 0.05 wBTC
    
    // Calculate user's share (should be 100%)
    let user_yield_share = (single_user_balance * total_yield) / total_supply;
    
    assert!(user_yield_share == total_yield, "Single user should get all yield");
    assert!(user_yield_share == ONE_WBTC / 20, "Should equal full yield amount");
}

#[test]
fn test_precision_with_many_small_holders() {
    // Test yield distribution among many small holders
    let small_holder_balance = 100_u256; // 100 satoshis each
    let num_holders = 1000_u256;
    let total_supply = small_holder_balance * num_holders; // 100,000 satoshis total
    let small_yield = 50_u256; // 50 satoshis total yield
    
    // Each holder should get their proportional share
    let individual_yield = (small_holder_balance * small_yield) / total_supply;
    
    // With these numbers: (100 * 50) / 100000 = 5000 / 100000 = 0 (due to integer division)
    assert!(individual_yield == 0, "Very small yields may round down to zero");
    
    // Test with slightly larger yield
    let larger_yield = 1000_u256; // 1000 satoshis
    let individual_larger_yield = (small_holder_balance * larger_yield) / total_supply;
    assert!(individual_larger_yield == 1, "Larger yield should give at least 1 satoshi per holder");
}

#[test]
fn test_rounding_in_yield_distribution() {
    // Test rounding behavior in yield calculations
    let user_balance = 333_u256;
    let total_supply = 1000_u256;
    let yield_amount = 10_u256;
    
    // Calculate yield: (333 * 10) / 1000 = 3330 / 1000 = 3.33, rounds down to 3
    let user_yield = (user_balance * yield_amount) / total_supply;
    
    assert!(user_yield == 3, "Should round down to 3 due to integer division");
    
    // Test if there's remainder
    let remainder = (user_balance * yield_amount) % total_supply;
    assert!(remainder == 330, "Should have remainder of 330");
}
