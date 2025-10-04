#[cfg(test)]
mod test_simplified_vault {
    use stackbits_vault::vault_swbtc::{
        get_enhanced_vault_config,
        calculate_vault_apy, EnhancedVaultConfig
    };
    use stackbits_vault::strategy::VesuAdapter::{get_default_vesu_config};
    use starknet::ContractAddress;
    use core::traits::TryInto;

    fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress) {
        let vault: ContractAddress = 0x123_felt252.try_into().unwrap();
        let alice: ContractAddress = 0x456_felt252.try_into().unwrap();
        let bob: ContractAddress = 0x789_felt252.try_into().unwrap();
        (vault, alice, bob)
    }

    fn get_test_enhanced_config() -> EnhancedVaultConfig {
        let (vault, _, _) = get_test_addresses();
        let asset_token: ContractAddress = 0x1_felt252.try_into().unwrap();
        let share_token: ContractAddress = 0x2_felt252.try_into().unwrap();
        
        EnhancedVaultConfig {
            asset_token,
            share_token,
            owner: vault,
            vesu_config: get_default_vesu_config(),
            target_idle_bps: 1000, // 10% idle
            auto_invest_enabled: true,
            min_investment_amount: 500000, // 0.5 wBTC minimum
        }
    }

    #[test]
    fn test_enhanced_vault_config() {
        let config = get_enhanced_vault_config();
        
        // Test basic configuration values
        assert!(config.target_idle_bps <= 10000, "Target idle should be valid percentage");
        assert!(config.min_investment_amount > 0, "Min investment should be positive");
        
        // Test that auto invest is configured reasonably
        assert!(config.target_idle_bps >= 500, "Should keep some idle funds"); // >= 5%
    }

    #[test] 
    fn test_get_test_config() {
        let config = get_test_enhanced_config();
        
        assert!(config.target_idle_bps == 1000, "Should have 10% target idle");
        assert!(config.auto_invest_enabled == true, "Should have auto invest enabled");
        assert!(config.min_investment_amount == 500000, "Should have correct min amount");
    }

    #[test]
    fn test_calculate_vault_apy_basic() {
        let current_assets = 10000000_u256; // 10 wBTC
        let start_assets = 9500000_u256; // 9.5 wBTC (5.26% gain) 
        let time_period = 86400_u64; // 1 day
        
        let apy = calculate_vault_apy(current_assets, start_assets, time_period);
        
        // APY should be positive when current > start
        assert!(apy > 0, "APY should be positive for gains");
        
        // APY should be very high for 1 day period (annualized)
        assert!(apy > 1000, "APY should be high when annualized from 1 day"); // > 10% 
    }

    #[test]
    fn test_calculate_vault_apy_loss() {
        let current_assets = 9500000_u256; // 9.5 wBTC
        let start_assets = 10000000_u256; // 10 wBTC (loss)
        let time_period = 86400_u64; // 1 day
        
        let apy = calculate_vault_apy(current_assets, start_assets, time_period);
        
        // APY should be 0 or minimal for losses (we don't show negative APY)
        assert!(apy == 0, "APY should be 0 for losses");
    }

    #[test]
    fn test_calculate_vault_apy_no_change() {
        let current_assets = 10000000_u256; // 10 wBTC
        let start_assets = 10000000_u256; // 10 wBTC (no change)
        let time_period = 86400_u64; // 1 day
        
        let apy = calculate_vault_apy(current_assets, start_assets, time_period);
        
        // APY should be 0 when no change
        assert!(apy == 0, "APY should be 0 when no gains");
    }
}