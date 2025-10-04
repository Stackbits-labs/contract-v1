use stackbits_vault::swbtc::{
    get_token_name, 
    get_token_symbol, 
    get_token_decimals, 
    get_default_token_info, 
    is_vault_authorized,
    TokenInfo
};
use starknet::ContractAddress;

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let vault = starknet::contract_address_const::<0x123>();
    let owner = starknet::contract_address_const::<0x456>();
    let alice = starknet::contract_address_const::<0x789>();
    let bob = starknet::contract_address_const::<0xabc>();
    (vault, owner, alice, bob)
}

#[test]
fn test_swbtc_token_info() {
    let name = get_token_name();
    let symbol = get_token_symbol();
    let decimals = get_token_decimals();
    
    assert(name == "Staked Wrapped BTC", 'Wrong token name');
    assert(symbol == "swBTC", 'Wrong token symbol');
    assert(decimals == 18, 'Wrong decimals');
}

#[test]
fn test_default_token_info() {
    let token_info = get_default_token_info();
    
    assert(token_info.decimals == 18, 'Wrong decimals');
    assert(token_info.total_supply == 0, 'Wrong initial supply');
}

#[test]
fn test_vault_authorization() {
    let (vault, _, alice, _) = get_test_addresses();
    
    // Vault should be authorized
    assert(is_vault_authorized(vault, vault) == true, 'Vault should be authorized');
    
    // Other addresses should not be authorized
    assert(is_vault_authorized(vault, alice) == false, 'Alice should not be authorized');
}

#[test]
fn test_token_info_struct() {
    let token_info = TokenInfo {
        decimals: 18,
        total_supply: 1000000,
    };
    
    assert(token_info.decimals == 18, 'Wrong decimals in struct');
    assert(token_info.total_supply == 1000000, 'Wrong supply in struct');
}