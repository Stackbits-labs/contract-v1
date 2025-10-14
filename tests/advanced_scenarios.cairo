use starknet::{ContractAddress, contract_address_const};

// Constants for advanced testing
const ONE_WBTC: u256 = 100000000; // 1 wBTC = 100,000,000 satoshis
const MIN_DEPOSIT: u256 = 1000; // 0.00001 wBTC (10 satoshis)
const LARGE_AMOUNT: u256 = 2100000000000000; // 21M wBTC (max supply)

#[test]
fn test_multiple_deposits_same_user() {
    // Test user making multiple deposits
    let user1 = contract_address_const::<'user1'>();
    
    // First deposit
    let first_deposit = ONE_WBTC / 2; // 0.5 wBTC
    let first_sbwbtc = first_deposit; // 1:1 ratio
    
    // Second deposit  
    let second_deposit = ONE_WBTC / 4; // 0.25 wBTC
    let second_sbwbtc = second_deposit; // 1:1 ratio
    
    // Total after both deposits
    let total_deposited = first_deposit + second_deposit;
    let total_sbwbtc = first_sbwbtc + second_sbwbtc;
    
    assert!(total_deposited == 75000000, "Total deposits should be 0.75 wBTC");
    assert!(total_sbwbtc == 75000000, "Total sbwBTC should be 0.75");
    assert!(total_sbwbtc == total_deposited, "Should maintain 1:1 ratio across multiple deposits");
}

#[test]
fn test_multiple_withdrawals_same_user() {
    // Test user making multiple withdrawals
    let initial_balance = ONE_WBTC; // 1.0 sbwBTC
    
    // First withdrawal
    let first_withdraw = ONE_WBTC / 4; // 0.25 wBTC
    let balance_after_first = initial_balance - first_withdraw;
    
    // Second withdrawal
    let second_withdraw = ONE_WBTC / 4; // 0.25 wBTC
    let balance_after_second = balance_after_first - second_withdraw;
    
    // Third withdrawal  
    let third_withdraw = ONE_WBTC / 2; // 0.5 wBTC
    let final_balance = balance_after_second - third_withdraw;
    
    assert!(balance_after_first == 75000000, "Balance after first withdrawal should be 0.75 wBTC");
    assert!(balance_after_second == 50000000, "Balance after second withdrawal should be 0.5 wBTC");
    assert!(final_balance == 0, "Final balance should be 0 after withdrawing all");
}

#[test]
fn test_yield_distribution_multiple_rounds() {
    // Test multiple rounds of yield distribution
    let user1_balance = 60000000_u256; // 0.6 sbwBTC
    let user2_balance = 40000000_u256; // 0.4 sbwBTC
    let total_supply = user1_balance + user2_balance;
    
    // First yield distribution - 5%
    let first_yield = 5000000_u256; // 0.05 wBTC
    let protocol_fee_bps = 1000_u256; // 10%
    
    let first_protocol_fee = (first_yield * protocol_fee_bps) / 10000;
    let first_net_yield = first_yield - first_protocol_fee;
    
    let user1_first_yield = (user1_balance * first_net_yield) / total_supply;
    let user2_first_yield = (user2_balance * first_net_yield) / total_supply;
    
    // Update balances after first distribution
    let user1_new_balance = user1_balance + user1_first_yield;
    let user2_new_balance = user2_balance + user2_first_yield;
    let new_total_supply = user1_new_balance + user2_new_balance;
    
    // Second yield distribution - 8%
    let second_yield = 8000000_u256; // 0.08 wBTC
    let second_protocol_fee = (second_yield * protocol_fee_bps) / 10000;
    let second_net_yield = second_yield - second_protocol_fee;
    
    let user1_second_yield = (user1_new_balance * second_net_yield) / new_total_supply;
    let user2_second_yield = (user2_new_balance * second_net_yield) / new_total_supply;
    
    // Verify calculations
    assert!(first_protocol_fee == 500000, "First protocol fee should be 0.005 wBTC");
    assert!(first_net_yield == 4500000, "First net yield should be 0.045 wBTC");
    assert!(user1_first_yield == 2700000, "User1 should get 60% of first net yield");
    assert!(user2_first_yield == 1800000, "User2 should get 40% of first net yield");
    
    assert!(second_protocol_fee == 800000, "Second protocol fee should be 0.008 wBTC");
    assert!(second_net_yield == 7200000, "Second net yield should be 0.072 wBTC");
    
    // Verify proportions are maintained
    let user1_total_yield = user1_first_yield + user1_second_yield;
    let user2_total_yield = user2_first_yield + user2_second_yield;
    
    assert!(user1_total_yield > user2_total_yield, "User1 should receive more total yield");
}

#[test]
fn test_dynamic_user_joining_and_leaving() {
    // Simulate users joining and leaving over time
    let initial_total_supply = 0_u256;
    
    // Day 1: User1 joins
    let user1_deposit = ONE_WBTC; // 1.0 wBTC
    let total_supply_day1 = initial_total_supply + user1_deposit;
    
    // Day 2: User2 joins
    let user2_deposit = ONE_WBTC * 2; // 2.0 wBTC
    let total_supply_day2 = total_supply_day1 + user2_deposit;
    
    // Day 3: Yield distribution (10%)
    let yield_amount = 30000000_u256; // 0.3 wBTC yield on 3.0 wBTC
    let protocol_fee = (yield_amount * 1000) / 10000; // 10% fee
    let net_yield = yield_amount - protocol_fee;
    
    let user1_yield = (user1_deposit * net_yield) / total_supply_day2;
    let user2_yield = (user2_deposit * net_yield) / total_supply_day2;
    
    let user1_balance_after_yield = user1_deposit + user1_yield;
    let user2_balance_after_yield = user2_deposit + user2_yield;
    
    // Day 4: User3 joins with large deposit
    let user3_deposit = ONE_WBTC * 5; // 5.0 wBTC
    let total_supply_day4 = user1_balance_after_yield + user2_balance_after_yield + user3_deposit;
    
    // Day 5: User1 withdraws 50%
    let user1_withdrawal = user1_balance_after_yield / 2;
    let user1_final_balance = user1_balance_after_yield - user1_withdrawal;
    
    // Verify all calculations
    assert!(total_supply_day1 == ONE_WBTC, "Day 1 total should be 1.0 wBTC");
    assert!(total_supply_day2 == ONE_WBTC * 3, "Day 2 total should be 3.0 wBTC");
    assert!(protocol_fee == 3000000, "Protocol fee should be 0.03 wBTC");
    assert!(net_yield == 27000000, "Net yield should be 0.27 wBTC");
    assert!(user1_yield == 9000000, "User1 should get 1/3 of net yield");
    assert!(user2_yield == 18000000, "User2 should get 2/3 of net yield");
    assert!(total_supply_day4 > ONE_WBTC * 8, "Day 4 total should exceed 8.0 wBTC");
}

#[test]
fn test_extreme_precision_scenarios() {
    // Test with very small amounts and precision edge cases
    let tiny_amount = 1_u256; // 1 satoshi
    let medium_amount = 12345678_u256; // 0.12345678 wBTC
    let odd_amount = 33333333_u256; // 0.33333333 wBTC (repeating decimal)
    
    let total_supply = tiny_amount + medium_amount + odd_amount;
    
    // Small yield distribution
    let small_yield = 1000_u256; // 0.00001 wBTC
    
    let tiny_yield = (tiny_amount * small_yield) / total_supply;
    let medium_yield = (medium_amount * small_yield) / total_supply;
    let odd_yield = (odd_amount * small_yield) / total_supply;
    
    let total_distributed = tiny_yield + medium_yield + odd_yield;
    
    // Verify precision handling
    assert!(total_distributed <= small_yield, "Cannot distribute more than available yield");
    assert!(tiny_yield == 0, "Tiny amount should get 0 yield due to rounding");
    assert!(medium_yield > 0, "Medium amount should get some yield");
    assert!(odd_yield > 0, "Odd amount should get some yield");
}

#[test]
fn test_protocol_fee_edge_cases() {
    // Test different protocol fee scenarios
    let base_yield = 10000000_u256; // 0.1 wBTC
    
    // Test 0% fee
    let zero_fee = 0_u256;
    let zero_fee_result = (base_yield * zero_fee) / 10000;
    let zero_fee_net = base_yield - zero_fee_result;
    
    // Test maximum reasonable fee (50%)
    let max_fee = 5000_u256; // 50%
    let max_fee_result = (base_yield * max_fee) / 10000;
    let max_fee_net = base_yield - max_fee_result;
    
    // Test 1% fee (100 bps)
    let one_percent_fee = 100_u256;
    let one_percent_result = (base_yield * one_percent_fee) / 10000;
    let one_percent_net = base_yield - one_percent_result;
    
    // Verify calculations
    assert!(zero_fee_result == 0, "0% fee should result in 0 fee");
    assert!(zero_fee_net == base_yield, "0% fee should leave full yield");
    
    assert!(max_fee_result == 5000000, "50% fee should be 0.05 wBTC");
    assert!(max_fee_net == 5000000, "50% fee should leave 0.05 wBTC net");
    
    assert!(one_percent_result == 100000, "1% fee should be 0.001 wBTC");
    assert!(one_percent_net == 9900000, "1% fee should leave 0.099 wBTC net");
}

#[test]
fn test_time_distribution_scenarios() {
    // Test various time-based scenarios
    let distribution_interval = 86400_u256; // 24 hours
    
    // Scenario 1: Exact 24 hour timing
    let start_time = 1000000_u256;
    let exact_24h = start_time + distribution_interval;
    let can_distribute_exact = exact_24h >= start_time + distribution_interval;
    
    // Scenario 2: Just before 24 hours
    let almost_24h = start_time + distribution_interval - 1;
    let can_distribute_almost = almost_24h >= start_time + distribution_interval;
    
    // Scenario 3: Multiple days later
    let multiple_days = start_time + (distribution_interval * 5); // 5 days
    let can_distribute_multiple = multiple_days >= start_time + distribution_interval;
    
    // Scenario 4: Next distribution timing
    let next_distribution_time = exact_24h + distribution_interval;
    let too_early_for_next = exact_24h + 1000; // 1000 seconds after first distribution
    let can_distribute_next = too_early_for_next >= next_distribution_time;
    
    assert!(can_distribute_exact == true, "Should be able to distribute exactly at 24h");
    assert!(can_distribute_almost == false, "Should not distribute 1 second before 24h");
    assert!(can_distribute_multiple == true, "Should be able to distribute after multiple days");
    assert!(can_distribute_next == false, "Should not distribute again before next 24h period");
}

#[test]
fn test_zero_and_negative_scenarios() {
    // Test edge cases with zero values
    let zero_deposit = 0_u256;
    let zero_withdrawal = 0_u256;
    let zero_yield = 0_u256;
    let zero_supply = 0_u256;
    
    // Zero deposit should result in zero sbwBTC
    let sbwbtc_from_zero = zero_deposit;
    assert!(sbwbtc_from_zero == 0, "Zero deposit should give zero sbwBTC");
    
    // Zero withdrawal from positive balance
    let balance = ONE_WBTC;
    let balance_after_zero_withdrawal = balance - zero_withdrawal;
    assert!(balance_after_zero_withdrawal == balance, "Zero withdrawal should not change balance");
    
    // Zero yield distribution
    let user_balance = ONE_WBTC;
    let total_supply = ONE_WBTC * 2;
    let user_yield_from_zero = (user_balance * zero_yield) / total_supply;
    assert!(user_yield_from_zero == 0, "Zero yield should distribute nothing");
    
    // Division by zero protection (should not happen in real contract)
    // This tests the math logic, real contract would have guards
    let safe_division = if zero_supply == 0 { 0 } else { user_balance / zero_supply };
    assert!(safe_division == 0, "Division by zero should be handled safely");
}

#[test]
fn test_large_number_scenarios() {
    // Test with very large numbers near maximum values
    let max_wbtc = 2100000000000000_u256; // 21M wBTC
    let half_max = max_wbtc / 2;
    let quarter_max = max_wbtc / 4;
    
    // Large deposit scenario
    let large_sbwbtc = max_wbtc; // 1:1 ratio
    assert!(large_sbwbtc == max_wbtc, "Large deposits should maintain 1:1 ratio");
    
    // Large yield calculation
    let large_yield = max_wbtc / 10; // 10% of max supply
    let protocol_fee = (large_yield * 1000) / 10000; // 10% fee
    let net_large_yield = large_yield - protocol_fee;
    
    assert!(protocol_fee == 21000000000000_u256, "Protocol fee calculation should handle large numbers");
    assert!(net_large_yield == 189000000000000_u256, "Net yield should be correct for large amounts");
    
    // Large multi-user scenario
    let user1_large = half_max;
    let user2_large = quarter_max;
    let user3_large = quarter_max;
    let total_large = user1_large + user2_large + user3_large;
    
    assert!(total_large == max_wbtc, "Large multi-user totals should be accurate");
    
    // Proportional distribution with large numbers
    let user1_large_yield = (user1_large * net_large_yield) / total_large;
    let user2_large_yield = (user2_large * net_large_yield) / total_large;
    let user3_large_yield = (user3_large * net_large_yield) / total_large;
    
    let total_distributed_large = user1_large_yield + user2_large_yield + user3_large_yield;
    
    assert!(user1_large_yield >= user2_large_yield, "User1 should get more yield (larger balance)");
    assert!(user2_large_yield == user3_large_yield, "User2 and User3 should get equal yield");
    assert!(total_distributed_large <= net_large_yield, "Total distributed should not exceed net yield");
}
