use stackbits_vault::interfaces::{ISnip22VaultDispatcher, ISnip22VaultDispatcherTrait, Deposit, Withdraw};
use starknet::ContractAddress;

#[test]
fn test_snip22_interface_types() {
    // Test that event types are properly defined
    let deposit_event = Deposit {
        user: starknet::contract_address_const::<0x1>(),
        receiver: starknet::contract_address_const::<0x2>(),
        assets: 1000_u256,
        shares: 1000_u256,
    };
    
    let withdraw_event = Withdraw {
        user: starknet::contract_address_const::<0x1>(),
        receiver: starknet::contract_address_const::<0x2>(),
        owner: starknet::contract_address_const::<0x3>(),
        assets: 500_u256,
        shares: 500_u256,
    };
    
    // Verify the events can be created
    assert(deposit_event.assets == 1000_u256, 'Invalid deposit assets');
    assert(withdraw_event.shares == 500_u256, 'Invalid withdraw shares');
}