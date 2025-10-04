use stackbits_vault::vault::{VaultInfo, get_vault_info};
use stackbits_vault::strategy::{StrategyInfo, get_default_strategy};
use stackbits_vault::utils::{calculate_percentage, safe_add, MAX_BPS, MIN_DEPOSIT};

#[test]
fn test_vault_info() {
    let vault_info = get_vault_info();
    assert(vault_info.total_assets == 0, 'Invalid initial assets');
}

#[test]
fn test_strategy_info() {
    let strategy_info = get_default_strategy();
    assert(strategy_info.name == 'default_strategy', 'Invalid strategy name');
    assert(strategy_info.active == false, 'Strategy should be inactive');
}

#[test]
fn test_math_utils() {
    let result = calculate_percentage(1000, 10);
    assert(result == 100, 'Invalid percentage calculation');
    
    let safe_result = safe_add(100, 200);
    match safe_result {
        Option::Some(value) => assert(value == 300, 'Invalid safe add'),
        Option::None => core::panic_with_felt252('Safe add should not fail')
    };
}

#[test]
fn test_constants() {
    assert(MAX_BPS == 10000, 'Invalid MAX_BPS');
    assert(MIN_DEPOSIT == 1000, 'Invalid MIN_DEPOSIT');
}
