#[cfg(test)]
mod test_fee_management {
    use stackbits_vault::vault_swbtc::{
        FeeConfig, KeeperConfig, FeePreview, fee_constants,
        preview_fees, harvest, validate_fee_config, update_keeper,
        get_default_fee_config, get_default_keeper_config,
        calculate_fee_shares, calculate_time_weighted_management_fee,
        get_enhanced_vault_config, total_assets_with_strategy
    };
    use stackbits_vault::interfaces::{FeesCharged, HarvestExecuted, KeeperUpdated};
    use stackbits_vault::strategy::VesuAdapter::{get_default_vesu_config};
    use starknet::ContractAddress;

    fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
        let vault = starknet::contract_address_const::<0x123>();
        let treasury = starknet::contract_address_const::<0x456>();
        let keeper = starknet::contract_address_const::<0x789>();
        let owner = starknet::contract_address_const::<0xabc>();
        (vault, treasury, keeper, owner)
    }

    fn get_test_fee_config(current_timestamp: u64) -> FeeConfig {
        let (_, treasury, _, _) = get_test_addresses();
        FeeConfig {
            treasury,
            management_fee_bps: 200, // 2% annual
            performance_fee_bps: 2000, // 20%
            last_fee_timestamp: current_timestamp - 86400, // 1 day ago
            high_water_mark: 10000000, // 10 wBTC
        }
    }

    fn get_test_keeper_config() -> KeeperConfig {
        let (_, _, keeper, _) = get_test_addresses();
        KeeperConfig {
            keeper,
            authorized: true,
        }
    }

    #[test]
    fn test_fee_constants() {
        assert!(fee_constants::SECONDS_PER_YEAR == 31536000, "Seconds per year should be correct");
        assert!(fee_constants::BASIS_POINTS_SCALE == 10000, "Basis points scale should be 10000");
        assert!(fee_constants::MAX_MANAGEMENT_FEE == 500, "Max management fee should be 5%");
        assert!(fee_constants::MAX_PERFORMANCE_FEE == 5000, "Max performance fee should be 50%");
    }

    #[test]
    fn test_validate_fee_config_valid() {
        let current_timestamp = 1000000_u64;
        let fee_config = get_test_fee_config(current_timestamp);
        
        let result = validate_fee_config(fee_config);
        match result {
            Result::Ok(()) => {
                // Success - fees are within limits
            },
            Result::Err(_) => panic!("Valid fee config should pass validation")
        }
    }

    #[test]
    fn test_validate_fee_config_management_fee_too_high() {
        let current_timestamp = 1000000_u64;
        let mut fee_config = get_test_fee_config(current_timestamp);
        fee_config.management_fee_bps = 600; // 6% - too high
        
        let result = validate_fee_config(fee_config);
        match result {
            Result::Err(error) => {
                assert!(error == 'Management fee too high', "Should reject high management fee");
            },
            Result::Ok(()) => panic!("Should reject high management fee")
        }
    }

    #[test]
    fn test_validate_fee_config_performance_fee_too_high() {
        let current_timestamp = 1000000_u64;
        let mut fee_config = get_test_fee_config(current_timestamp);
        fee_config.performance_fee_bps = 6000; // 60% - too high
        
        let result = validate_fee_config(fee_config);
        match result {
            Result::Err(error) => {
                assert!(error == 'Performance fee too high', "Should reject high performance fee");
            },
            Result::Ok(()) => panic!("Should reject high performance fee")
        }
    }

    #[test]
    fn test_calculate_fee_shares() {
        let fee_assets = 1000000_u256; // 1 wBTC fee
        let total_assets = 10000000_u256; // 10 wBTC total
        let total_supply = 10000000_u256; // 10 shares total
        
        let fee_shares = calculate_fee_shares(fee_assets, total_assets, total_supply);
        
        // Should get 1 share for 1 wBTC fee (1:1 ratio)
        assert!(fee_shares == 1000000, "Fee shares should be proportional");
    }

    #[test]
    fn test_calculate_fee_shares_empty_vault() {
        let fee_assets = 1000000_u256;
        let total_assets = 0_u256;
        let total_supply = 0_u256;
        
        let fee_shares = calculate_fee_shares(fee_assets, total_assets, total_supply);
        
        // Should get 1:1 shares when vault is empty
        assert!(fee_shares == fee_assets, "Should get 1:1 shares when empty");
    }

    #[test]
    fn test_calculate_time_weighted_management_fee() {
        let total_assets = 10000000_u256; // 10 wBTC
        let management_fee_bps = 200_u256; // 2% annual
        let time_elapsed = 86400_u64; // 1 day
        
        let mgmt_fee = calculate_time_weighted_management_fee(
            total_assets, 
            management_fee_bps, 
            time_elapsed
        );
        
        // 2% annual on 10 wBTC for 1 day = 200000 * 86400 / 31536000 ≈ 547 satoshis
        assert!(mgmt_fee > 0, "Management fee should be calculated");
        assert!(mgmt_fee < total_assets / 100, "Management fee should be reasonable");
    }

    #[test]
    fn test_preview_fees_no_profit() {
        let vault_balance = 8000000_u256; // 8 wBTC in vault
        let vesu_config = get_default_vesu_config();
        let fee_config = get_test_fee_config(1000000);
        let total_supply = 10000000_u256;
        let current_timestamp = 1086400_u64; // 1 day later
        
        let fee_preview = preview_fees(
            vault_balance,
            vesu_config,
            fee_config,
            total_supply,
            current_timestamp
        );
        
        // Should have no performance fees (no profit)
        assert!(fee_preview.performance_fee_shares == 0, "No performance fee without profit");
        assert!(fee_preview.projected_profit == 0, "No profit projected");
        
        // Should have management fees for 1 day
        assert!(fee_preview.management_fee_shares > 0, "Should have management fees");
        assert!(fee_preview.time_since_last_harvest == 86400, "Time should be 1 day");
    }

    #[test]
    fn test_preview_fees_with_profit() {
        let vault_balance = 12000000_u256; // 12 wBTC in vault (above HWM of 10)
        let vesu_config = get_default_vesu_config();
        let fee_config = get_test_fee_config(1000000);
        let total_supply = 10000000_u256;
        let current_timestamp = 1086400_u64;
        
        let fee_preview = preview_fees(
            vault_balance,
            vesu_config,
            fee_config,
            total_supply,
            current_timestamp
        );
        
        // Should have performance fees (profit = 12 - 10 = 2 wBTC)
        assert!(fee_preview.performance_fee_shares > 0, "Should have performance fees");
        assert!(fee_preview.projected_profit == 2000000, "Profit should be 2 wBTC");
        
        // Should also have management fees
        assert!(fee_preview.management_fee_shares > 0, "Should have management fees");
    }

    #[test]
    fn test_harvest_unauthorized_keeper() {
        let vault_balance = 10000000_u256;
        let vesu_config = get_default_vesu_config();
        let fee_config = get_test_fee_config(1000000);
        let total_supply = 10000000_u256;
        let current_timestamp = 1086400_u64;
        let unauthorized_caller = starknet::contract_address_const::<0xbad>();
        let keeper_config = get_test_keeper_config();
        
        let result = harvest(
            vault_balance,
            vesu_config,
            fee_config,
            total_supply,
            current_timestamp,
            unauthorized_caller,
            keeper_config
        );
        
        match result {
            Result::Err(error) => {
                assert!(error == 'Unauthorized keeper', "Should reject unauthorized keeper");
            },
            Result::Ok(_) => panic!("Should reject unauthorized keeper")
        }
    }

    #[test]
    fn test_harvest_success() {
        let vault_balance = 12000000_u256; // 12 wBTC (profit of 2 wBTC)
        let vesu_config = get_default_vesu_config();
        let fee_config = get_test_fee_config(1000000);
        let total_supply = 10000000_u256;
        let current_timestamp = 1086400_u64;
        let keeper_config = get_test_keeper_config();
        
        let result = harvest(
            vault_balance,
            vesu_config,
            fee_config,
            total_supply,
            current_timestamp,
            keeper_config.keeper,
            keeper_config
        );
        
        match result {
            Result::Ok((updated_fee_config, mgmt_fee_shares, perf_fee_shares, fees_event, harvest_event)) => {
                // Check updated config
                assert!(updated_fee_config.last_fee_timestamp == current_timestamp, "Timestamp should be updated");
                assert!(updated_fee_config.high_water_mark >= fee_config.high_water_mark, "HWM should not decrease");
                
                // Check fees
                assert!(perf_fee_shares > 0, "Should have performance fees");
                assert!(mgmt_fee_shares > 0, "Should have management fees");
                
                // Check events
                assert!(fees_event.performance_fee_shares == perf_fee_shares, "Event should match perf fees");
                assert!(fees_event.management_fee_shares == mgmt_fee_shares, "Event should match mgmt fees");
                assert!(harvest_event.profit > 0, "Harvest event should show profit");
            },
            Result::Err(_) => panic!("Harvest should succeed")
        }
    }

    #[test]
    fn test_update_keeper_success() {
        let keeper_config = get_test_keeper_config();
        let (_, _, new_keeper, owner) = get_test_addresses();
        
        let result = update_keeper(
            keeper_config,
            new_keeper,
            true,
            owner,
            owner
        );
        
        match result {
            Result::Ok((updated_config, event)) => {
                assert!(updated_config.keeper == new_keeper, "Keeper should be updated");
                assert!(updated_config.authorized == true, "Keeper should be authorized");
                assert!(event.keeper == new_keeper, "Event should show new keeper");
                assert!(event.authorized == true, "Event should show authorized");
            },
            Result::Err(_) => panic!("Keeper update should succeed")
        }
    }

    #[test]
    fn test_update_keeper_unauthorized() {
        let keeper_config = get_test_keeper_config();
        let (_, _, new_keeper, owner) = get_test_addresses();
        let unauthorized = starknet::contract_address_const::<0xbad>();
        
        let result = update_keeper(
            keeper_config,
            new_keeper,
            true,
            unauthorized, // Not the owner
            owner
        );
        
        match result {
            Result::Err(error) => {
                assert!(error == 'Only owner can update keeper', "Should reject unauthorized update");
            },
            Result::Ok(_) => panic!("Should reject unauthorized keeper update")
        }
    }

    #[test]
    fn test_default_configs() {
        let (_, treasury, keeper, _) = get_test_addresses();
        let current_timestamp = 1000000_u64;
        
        // Test default fee config
        let fee_config = get_default_fee_config(treasury, current_timestamp);
        assert!(fee_config.treasury == treasury, "Treasury should be set");
        assert!(fee_config.management_fee_bps == 200, "Default management fee should be 2%");
        assert!(fee_config.performance_fee_bps == 2000, "Default performance fee should be 20%");
        assert!(fee_config.last_fee_timestamp == current_timestamp, "Timestamp should be set");
        
        // Test default keeper config
        let keeper_config = get_default_keeper_config(keeper);
        assert!(keeper_config.keeper == keeper, "Keeper should be set");
        assert!(keeper_config.authorized == true, "Keeper should be authorized by default");
    }

    #[test]
    fn test_fee_preview_structure() {
        let fee_preview = FeePreview {
            management_fee_shares: 100000,
            performance_fee_shares: 200000,
            total_fee_shares: 300000,
            projected_profit: 1000000,
            time_since_last_harvest: 86400,
        };
        
        assert!(fee_preview.total_fee_shares == 300000, "Total should match sum");
        assert!(fee_preview.management_fee_shares + fee_preview.performance_fee_shares == fee_preview.total_fee_shares, "Total should equal sum of components");
    }
}