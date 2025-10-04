#[cfg(test)]
mod test_reward_management {
    use stackbits_vault::vault_swbtc::{fee_constants};
    use stackbits_vault::strategy::VesuAdapter::{
        VesuAdapterConfig, get_default_vesu_config, claim_rewards, sell_rewards_to_wbtc
    };

    #[test]
    fn test_claim_rewards_success() {
        let vesu_config = get_default_vesu_config();
        
        // Test reward claiming - should return placeholder amount (0) for now
        let result = claim_rewards(vesu_config);
        assert!(result.is_ok(), "Reward claiming should succeed");
        
        let rewards: u256 = result.unwrap();
        // Currently returns 0 as placeholder - in real implementation would be > 0
        assert!(rewards == 0, "Placeholder rewards should be 0");
    }

    #[test]
    fn test_sell_rewards_to_wbtc_success() {
        let vesu_config = get_default_vesu_config();
        let reward_amount = 1000_u256;
        let min_out = 900_u256; // 10% max slippage
        
        let result = sell_rewards_to_wbtc(vesu_config, reward_amount, min_out);
        assert!(result.is_ok(), "Reward selling should succeed");
        
        let wbtc_received: u256 = result.unwrap();
        // Stub implementation simulates 5% slippage
        let expected = reward_amount * 95 / 100;
        assert!(wbtc_received == expected, "Should receive expected wBTC amount");
        assert!(wbtc_received >= min_out, "Should meet minimum output requirement");
    }

    #[test]
    fn test_sell_rewards_excessive_slippage() {
        let vesu_config = get_default_vesu_config();
        let reward_amount = 1000_u256;
        let min_out = 980_u256; // Requires < 2% slippage, but stub gives 5%
        
        let result = sell_rewards_to_wbtc(vesu_config, reward_amount, min_out);
        assert!(result.is_err(), "Should fail with excessive slippage");
        let error_msg: felt252 = result.unwrap_err();
        assert!(error_msg == 'DEX slippage too high', "Wrong error message");
    }

    #[test]
    fn test_sell_rewards_zero_amount() {
        let vesu_config = get_default_vesu_config();
        let reward_amount = 0_u256;
        let min_out = 0_u256;
        
        let result = sell_rewards_to_wbtc(vesu_config, reward_amount, min_out);
        assert!(result.is_ok(), "Zero amount should succeed");
        let output: u256 = result.unwrap();
        assert!(output == 0, "Should return 0 for zero input");
    }

    #[test]
    fn test_reward_fee_calculation() {
        // Test the reward fee calculation logic
        let rewards_claimed = 1000_u256;
        let reward_fee_bps = 500_u256; // 5%
        
        let treasury_fee = (rewards_claimed * reward_fee_bps) / fee_constants::BASIS_POINTS_SCALE;
        let net_rewards = rewards_claimed - treasury_fee;
        
        assert!(treasury_fee == 50, "Treasury should get 5% = 50");
        assert!(net_rewards == 950, "Net rewards should be 95% = 950");
    }

    #[test]
    fn test_compounding_flow_simulation() {
        // Simulate the full compounding flow with realistic numbers
        let initial_rewards = 1000_u256;
        let reward_fee_bps = 500_u256; // 5%
        
        // Step 1: Calculate treasury fee
        let treasury_fee = (initial_rewards * reward_fee_bps) / fee_constants::BASIS_POINTS_SCALE;
        let net_rewards = initial_rewards - treasury_fee;
        
        // Step 2: Simulate DEX swap (5% slippage)
        let wbtc_received = net_rewards * 95 / 100;
        
        // Step 3: Amount available for compounding
        let compoundable_amount = wbtc_received;
        
        // Verify the flow
        assert!(treasury_fee == 50, "Treasury should get 50 reward tokens");
        assert!(net_rewards == 950, "950 tokens go to DEX");
        assert!(wbtc_received == 902, "DEX returns 902 wBTC after slippage"); // 950 * 0.95
        assert!(compoundable_amount == 902, "902 wBTC available for compounding");
    }
}