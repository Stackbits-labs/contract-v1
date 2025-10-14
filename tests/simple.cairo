use starknet::contract_address_const;
use snforge_std_deprecated::declare;

#[test]
fn test_basic_math() {
    let one_wbtc: u256 = 100000000; // 1 wBTC = 100,000,000 satoshis
    assert!(one_wbtc == 100000000, "One wBTC should equal 100 million satoshis");
    
    let half_wbtc = one_wbtc / 2;
    assert!(half_wbtc == 50000000, "Half wBTC should be 50 million satoshis");
    
    // Test yield calculation
    let principal = 100000000_u256; // 1 wBTC
    let yield_percentage = 1000_u256; // 10% in basis points
    let expected_yield = (principal * yield_percentage) / 10000;
    assert!(expected_yield == 10000000, "10% of 1 wBTC should be 0.1 wBTC");
}

#[test] 
fn test_address_creation() {
    let owner = contract_address_const::<'owner'>();
    let user1 = contract_address_const::<'user1'>();
    let user2 = contract_address_const::<'user2'>();
    
    assert!(owner != user1, "Addresses should be different");
    assert!(user1 != user2, "Addresses should be different");
    assert!(owner != user2, "Addresses should be different");
}

#[test]
fn test_proportional_distribution() {
    // Test proportional yield distribution logic
    let user1_balance = 70000000_u256; // 0.7 wBTC
    let user2_balance = 30000000_u256; // 0.3 wBTC
    let total_supply = user1_balance + user2_balance; // 1.0 wBTC
    
    let total_yield = 10000000_u256; // 0.1 wBTC yield
    
    let user1_yield = (user1_balance * total_yield) / total_supply;
    let user2_yield = (user2_balance * total_yield) / total_supply;
    
    assert!(user1_yield == 7000000, "User1 should get 70% of yield");
    assert!(user2_yield == 3000000, "User2 should get 30% of yield");
    assert!(user1_yield + user2_yield == total_yield, "Total yield should be distributed");
}

#[test]
fn test_protocol_fee_calculation() {
    let gross_yield = 10000000_u256; // 0.1 wBTC
    let protocol_fee_bps = 1000_u256; // 10% fee
    
    let protocol_fee = (gross_yield * protocol_fee_bps) / 10000;
    let net_yield = gross_yield - protocol_fee;
    
    assert!(protocol_fee == 1000000, "Protocol fee should be 0.01 wBTC");
    assert!(net_yield == 9000000, "Net yield should be 0.09 wBTC");
}
