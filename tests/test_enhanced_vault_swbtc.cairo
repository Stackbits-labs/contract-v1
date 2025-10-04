#[cfg(test)]
mod test_enhanced_vault_swbtc {
    use stackbits_vault::vault_swbtc::{
        enhanced_deposit, enhanced_withdraw, rebalance_idle, get_enhanced_vault_config,
        calculate_vault_apy, EnhancedVaultConfig, VaultState
    };
    use stackbits_vault::interfaces::{Deposit, Withdraw, Invest, Divest, Rebalance};
    use stackbits_vault::strategy::VesuAdapter::{VesuAdapterConfig, get_default_vesu_config};
    use starknet::ContractAddress;

    fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress) {
        let vault = starknet::contract_address_const::<0x123>();
        let alice = starknet::contract_address_const::<0x456>();
        let bob = starknet::contract_address_const::<0x789>();
        (vault, alice, bob)
    }

    fn get_test_enhanced_config() -> EnhancedVaultConfig {
        let (vault, _, _) = get_test_addresses();
        EnhancedVaultConfig {
            asset_token: starknet::contract_address_const::<0x1>(),
            share_token: starknet::contract_address_const::<0x2>(),
            owner: vault,
            vesu_config: get_default_vesu_config(),
            target_idle_bps: 1000, // 10% idle
            auto_invest_enabled: true,
            min_investment_amount: 500000, // 0.5 wBTC minimum
        }
    }

    #[test]
    fn test_enhanced_deposit_basic() {
        let config = get_test_enhanced_config();
        let (_, alice, _) = get_test_addresses();
        
        let assets = 1000000_u256; // 1 wBTC
        let vault_balance = 0_u256;
        let total_supply = 0_u256;
        let total_assets = 0_u256;
        
        let result = enhanced_deposit(
            assets, alice, vault_balance, total_supply, total_assets, config
        );
        
        match result {
            Result::Ok((shares, deposit_event, invest_event)) => {
                assert!(shares == assets, "Should get 1:1 shares when empty");
                assert!(deposit_event.assets == assets, "Deposit event should match assets");
                assert!(deposit_event.receiver == alice, "Receiver should match");
                
                // Should have invest event since auto_invest is enabled and amount > min
                match invest_event {
                    Option::Some(_invest) => {
                        // Investment should happen
                    },
                    Option::None => panic!("Should have investment event")
                }
            },
            Result::Err(_) => panic!("Deposit should succeed")
        }
    }

    #[test]
    fn test_enhanced_deposit_zero_assets() {
        let config = get_test_enhanced_config();
        let (_, alice, _) = get_test_addresses();
        
        let result = enhanced_deposit(0, alice, 0, 0, 0, config);
        
        match result {
            Result::Err(error) => {
                assert!(error == 'Zero assets to deposit', "Should reject zero deposits");
            },
            Result::Ok(_) => panic!("Should reject zero assets")
        }
    }

    #[test]
    fn test_enhanced_deposit_small_amount_no_auto_invest() {
        let mut config = get_test_enhanced_config();
        config.min_investment_amount = 2000000; // 2 wBTC minimum
        let (_, alice, _) = get_test_addresses();
        
        let assets = 1000000_u256; // 1 wBTC (below minimum)
        
        let result = enhanced_deposit(assets, alice, 0, 0, 0, config);
        
        match result {
            Result::Ok((shares, _deposit_event, invest_event)) => {
                assert!(shares == assets, "Should get shares");
                
                // Should NOT have invest event since amount < min
                match invest_event {
                    Option::None => {
                        // Correct - no investment
                    },
                    Option::Some(_) => panic!("Should not invest small amounts")
                }
            },
            Result::Err(_) => panic!("Deposit should succeed")
        }
    }

    #[test]
    fn test_enhanced_withdraw_sufficient_vault_balance() {
        let config = get_test_enhanced_config();
        let (_, alice, bob) = get_test_addresses();
        
        let assets = 500000_u256; // 0.5 wBTC
        let vault_balance = 1000000_u256; // 1 wBTC in vault
        let total_supply = 1000000_u256;
        let total_assets = 1000000_u256;
        
        let result = enhanced_withdraw(
            assets, alice, bob, vault_balance, total_supply, total_assets, config
        );
        
        match result {
            Result::Ok((shares, withdraw_event, divest_event)) => {
                assert!(withdraw_event.assets == assets, "Withdraw event should match");
                assert!(withdraw_event.receiver == alice, "Receiver should match");
                assert!(withdraw_event.owner == bob, "Owner should match");
                
                // Should NOT have divest event since vault has enough
                match divest_event {
                    Option::None => {
                        // Correct - no divestment needed
                    },
                    Option::Some(_) => panic!("Should not need to divest")
                }
            },
            Result::Err(_) => panic!("Withdraw should succeed")
        }
    }

    #[test]
    fn test_enhanced_withdraw_needs_divest() {
        let config = get_test_enhanced_config();
        let (_, alice, bob) = get_test_addresses();
        
        let assets = 1500000_u256; // 1.5 wBTC requested
        let vault_balance = 500000_u256; // Only 0.5 wBTC in vault
        let total_supply = 2000000_u256;
        let total_assets = 2000000_u256; // 2 wBTC total (1.5 in Vesu)
        
        let result = enhanced_withdraw(
            assets, alice, bob, vault_balance, total_supply, total_assets, config
        );
        
        match result {
            Result::Ok((shares, withdraw_event, divest_event)) => {
                assert!(withdraw_event.assets == assets, "Withdraw event should match");
                
                // Should have divest event since vault doesn't have enough
                match divest_event {
                    Option::Some(divest) => {
                        let expected_divest = assets - vault_balance;
                        assert!(divest.assets == expected_divest, "Should divest the difference");
                    },
                    Option::None => panic!("Should need to divest")
                }
            },
            Result::Err(_) => panic!("Withdraw should succeed")
        }
    }

    #[test]
    fn test_enhanced_withdraw_insufficient_total_assets() {
        let config = get_test_enhanced_config();
        let (_, alice, bob) = get_test_addresses();
        
        let assets = 3000000_u256; // 3 wBTC requested
        let vault_balance = 1000000_u256; // 1 wBTC in vault
        let total_supply = 2000000_u256;
        let total_assets = 2000000_u256; // Only 2 wBTC total
        
        let result = enhanced_withdraw(
            assets, alice, bob, vault_balance, total_supply, total_assets, config
        );
        
        match result {
            Result::Err(error) => {
                assert!(error == 'Insufficient total assets', "Should reject if not enough total assets");
            },
            Result::Ok(_) => panic!("Should reject insufficient assets")
        }
    }

    #[test]
    fn test_rebalance_idle_need_to_invest() {
        let config = get_test_enhanced_config();
        let current_vault_balance = 2000000_u256; // 2 wBTC idle (too much)
        let target_idle_bps = 1000_u256; // 10% target idle
        
        let result = rebalance_idle(current_vault_balance, target_idle_bps, config);
        
        match result {
            Result::Ok((invest_event, divest_event, rebalance_event)) => {
                // Should have invest event since too much idle
                match invest_event {
                    Option::Some(invest) => {
                        assert!(invest.assets > 0, "Should invest excess idle");
                    },
                    Option::None => panic!("Should need to invest")
                }
                
                // Should NOT have divest event
                match divest_event {
                    Option::None => {
                        // Correct
                    },
                    Option::Some(_) => panic!("Should not divest")
                }
                
                assert!(rebalance_event.idle_before == current_vault_balance, "Before balance should match");
            },
            Result::Err(_) => panic!("Rebalance should succeed")
        }
    }

    #[test]
    fn test_rebalance_idle_zero_assets() {
        let config = get_test_enhanced_config();
        let current_vault_balance = 0_u256;
        let target_idle_bps = 1000_u256;
        
        let result = rebalance_idle(current_vault_balance, target_idle_bps, config);
        
        match result {
            Result::Err(error) => {
                assert!(error == 'No assets to rebalance', "Should reject zero assets");
            },
            Result::Ok(_) => panic!("Should reject zero assets")
        }
    }

    #[test]
    fn test_calculate_vault_apy() {
        let initial_assets = 1000000_u256; // 1 wBTC
        let current_assets = 1100000_u256; // 1.1 wBTC (10% gain)
        let time_elapsed = 365 * 24 * 3600; // 1 year in seconds
        
        let apy = calculate_vault_apy(initial_assets, current_assets, time_elapsed);
        
        // Should return 10% in basis points (1000)
        assert!(apy == 1000, "Should calculate 10% APY");
    }

    #[test]
    fn test_calculate_vault_apy_no_gain() {
        let initial_assets = 1000000_u256;
        let current_assets = 900000_u256; // Loss
        let time_elapsed = 365 * 24 * 3600;
        
        let apy = calculate_vault_apy(initial_assets, current_assets, time_elapsed);
        
        // Should return 0 for losses
        assert!(apy == 0, "Should return 0 for losses");
    }

    #[test]
    fn test_enhanced_vault_config_creation() {
        let config = get_enhanced_vault_config();
        
        assert!(config.auto_invest_enabled, "Auto invest should be enabled by default");
        assert!(config.target_idle_bps == 1000, "Default idle should be 10%");
        assert!(config.min_investment_amount == 1000000, "Min investment should be 1 wBTC");
    }

    #[test]
    fn test_vault_state_structure() {
        let state = VaultState {
            total_supply: 1000000,
            vault_balance: 500000,
            last_rebalance: 12345678,
            total_invested: 2000000,
            total_divested: 500000,
        };
        
        assert!(state.total_supply == 1000000, "Total supply should be set");
        assert!(state.vault_balance == 500000, "Vault balance should be set");
        assert!(state.total_invested > state.total_divested, "Should have net investment");
    }
}