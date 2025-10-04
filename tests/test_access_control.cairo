#[cfg(test)]
mod test_access_control {
    use stackbits_vault::access_control::{
        AccessControlState, get_default_access_control, only_owner, only_keeper, when_not_paused,
        when_paused, nonreentrant_start, nonreentrant_end, transfer_ownership, accept_ownership,
        set_keeper, set_treasury, pause, unpause, validate_fee_params, roles, has_role, is_owner,
        is_keeper, is_treasury
    };
    use stackbits_vault::vault_swbtc::{
        set_fee_params, set_treasury_address, set_vesu_market, rescue_token,
        get_default_vault_access_control, FeeConfig, get_default_fee_config
    };
    use stackbits_vault::strategy::VesuAdapter::{VesuAdapterConfig, get_default_vesu_config};
    use starknet::ContractAddress;

    fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
        let owner = starknet::contract_address_const::<0x123>();
        let treasury = starknet::contract_address_const::<0x456>();
        let keeper = starknet::contract_address_const::<0x789>();
        let user = starknet::contract_address_const::<0xabc>();
        (owner, treasury, keeper, user)
    }

    #[test]
    fn test_default_access_control_creation() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        assert!(access_control.owner == owner, "Owner should match");
        assert!(access_control.treasury == treasury, "Treasury should match");
        assert!(access_control.keeper == keeper, "Keeper should match");
        assert!(!access_control.paused, "Should not be paused initially");
        assert!(!access_control.reentrancy_guard, "Reentrancy guard should be false");
        assert!(access_control.pending_owner == starknet::contract_address_const::<0>(), "No pending owner initially");
    }

    #[test]
    fn test_only_owner_success() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let result = only_owner(access_control, owner);
        assert!(result.is_ok(), "Owner should have access");
    }

    #[test]
    fn test_only_owner_failure() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let result = only_owner(access_control, user);
        assert!(result.is_err(), "User should not have owner access");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'AccessControl: not owner', "Wrong error message");
    }

    #[test]
    fn test_only_keeper_success_keeper() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let result = only_keeper(access_control, keeper);
        assert!(result.is_ok(), "Keeper should have access");
    }

    #[test]
    fn test_only_keeper_success_owner() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let result = only_keeper(access_control, owner);
        assert!(result.is_ok(), "Owner should have keeper access");
    }

    #[test]
    fn test_only_keeper_failure() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let result = only_keeper(access_control, user);
        assert!(result.is_err(), "User should not have keeper access");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'AccessControl: not keeper', "Wrong error message");
    }

    #[test]
    fn test_pause_unpause_flow() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let mut access_control = get_default_access_control(owner, treasury, keeper);
        let current_timestamp = 1000000_u64;
        
        // Initially not paused
        let result = when_not_paused(access_control);
        assert!(result.is_ok(), "Should not be paused initially");
        
        // Pause by owner
        let pause_result = pause(access_control, owner, current_timestamp);
        assert!(pause_result.is_ok(), "Owner should be able to pause");
        
        let (updated_state, pause_event) = pause_result.unwrap();
        access_control = updated_state;
        
        assert!(access_control.paused, "Should be paused after pause()");
        assert!(pause_event.paused_by == owner, "Pause event should show correct pauser");
        
        // Check paused state
        let paused_check = when_paused(access_control);
        assert!(paused_check.is_ok(), "Should recognize paused state");
        
        let not_paused_check = when_not_paused(access_control);
        assert!(not_paused_check.is_err(), "Should fail when_not_paused check");
        
        // Unpause by owner
        let unpause_result = unpause(access_control, owner, current_timestamp + 100);
        assert!(unpause_result.is_ok(), "Owner should be able to unpause");
        
        let (final_state, unpause_event) = unpause_result.unwrap();
        access_control = final_state;
        
        assert!(!access_control.paused, "Should not be paused after unpause()");
        assert!(unpause_event.unpaused_by == owner, "Unpause event should show correct unpauser");
    }

    #[test]
    fn test_pause_unauthorized() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let result = pause(access_control, user, 1000000_u64);
        assert!(result.is_err(), "User should not be able to pause");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'AccessControl: not owner', "Wrong error message");
    }

    #[test]
    fn test_ownership_transfer_flow() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let mut access_control = get_default_access_control(owner, treasury, keeper);
        let new_owner = starknet::contract_address_const::<0xdef>();
        let current_timestamp = 1000000_u64;
        
        // Initiate transfer
        let transfer_result = transfer_ownership(access_control, new_owner, owner, current_timestamp);
        assert!(transfer_result.is_ok(), "Owner should be able to initiate transfer");
        
        let (updated_state, transfer_event) = transfer_result.unwrap();
        access_control = updated_state;
        
        assert!(access_control.pending_owner == new_owner, "Pending owner should be set");
        assert!(access_control.owner == owner, "Current owner should remain unchanged");
        assert!(transfer_event.new_owner == new_owner, "Transfer event should show new owner");
        
        // Accept ownership
        let accept_result = accept_ownership(access_control, new_owner, current_timestamp + 100);
        assert!(accept_result.is_ok(), "New owner should be able to accept");
        
        let (final_state, accept_event) = accept_result.unwrap();
        access_control = final_state;
        
        assert!(access_control.owner == new_owner, "Owner should be updated");
        assert!(access_control.pending_owner == starknet::contract_address_const::<0>(), "Pending owner should be cleared");
        assert!(accept_event.previous_owner == owner, "Accept event should show previous owner");
        assert!(accept_event.new_owner == new_owner, "Accept event should show new owner");
    }

    #[test]
    fn test_ownership_transfer_unauthorized() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        let new_owner = starknet::contract_address_const::<0xdef>();
        
        let result = transfer_ownership(access_control, new_owner, user, 1000000_u64);
        assert!(result.is_err(), "User should not be able to initiate transfer");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'AccessControl: not owner', "Wrong error message");
    }

    #[test]
    fn test_reentrancy_guard() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let mut access_control = get_default_access_control(owner, treasury, keeper);
        
        // First call should succeed
        let result1 = nonreentrant_start(access_control);
        assert!(result1.is_ok(), "First reentrancy guard should succeed");
        
        access_control = result1.unwrap();
        assert!(access_control.reentrancy_guard, "Reentrancy guard should be active");
        
        // Second call should fail (reentrant)
        let result2 = nonreentrant_start(access_control);
        assert!(result2.is_err(), "Second reentrancy guard should fail");
        let error: felt252 = result2.unwrap_err();
        assert!(error == 'ReentrancyGuard: reentrant call', "Wrong error message");
        
        // End reentrancy guard
        access_control = nonreentrant_end(access_control);
        assert!(!access_control.reentrancy_guard, "Reentrancy guard should be cleared");
        
        // Should be able to start again
        let result3 = nonreentrant_start(access_control);
        assert!(result3.is_ok(), "Should be able to start guard again");
    }

    #[test]
    fn test_role_management() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let mut access_control = get_default_access_control(owner, treasury, keeper);
        let new_keeper = starknet::contract_address_const::<0xdef>();
        let new_treasury = starknet::contract_address_const::<0x111>();
        let current_timestamp = 1000000_u64;
        
        // Set new keeper
        let keeper_result = set_keeper(access_control, new_keeper, owner, current_timestamp);
        assert!(keeper_result.is_ok(), "Owner should be able to set keeper");
        
        let (updated_state, keeper_event) = keeper_result.unwrap();
        access_control = updated_state;
        
        assert!(access_control.keeper == new_keeper, "Keeper should be updated");
        assert!(keeper_event.account == new_keeper, "Keeper event should show new keeper");
        assert!(keeper_event.role == roles::KEEPER, "Event should show KEEPER role");
        
        // Set new treasury
        let treasury_result = set_treasury(access_control, new_treasury, owner, current_timestamp);
        assert!(treasury_result.is_ok(), "Owner should be able to set treasury");
        
        let (final_state, treasury_event) = treasury_result.unwrap();
        access_control = final_state;
        
        assert!(access_control.treasury == new_treasury, "Treasury should be updated");
        assert!(treasury_event.account == new_treasury, "Treasury event should show new treasury");
        assert!(treasury_event.role == roles::TREASURY, "Event should show TREASURY role");
    }

    #[test]
    fn test_has_role_function() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        // Test owner role
        assert!(has_role(access_control, roles::OWNER, owner), "Owner should have OWNER role");
        assert!(!has_role(access_control, roles::OWNER, user), "User should not have OWNER role");
        
        // Test keeper role
        assert!(has_role(access_control, roles::KEEPER, keeper), "Keeper should have KEEPER role");
        assert!(has_role(access_control, roles::KEEPER, owner), "Owner should have KEEPER role");
        assert!(!has_role(access_control, roles::KEEPER, user), "User should not have KEEPER role");
        
        // Test treasury role
        assert!(has_role(access_control, roles::TREASURY, treasury), "Treasury should have TREASURY role");
        assert!(has_role(access_control, roles::TREASURY, owner), "Owner should have TREASURY role");
        assert!(!has_role(access_control, roles::TREASURY, user), "User should not have TREASURY role");
    }

    #[test]
    fn test_validate_fee_params_success() {
        let result = validate_fee_params(200, 2000, 500); // 2%, 20%, 5%
        assert!(result.is_ok(), "Valid fee params should succeed");
    }

    #[test]
    fn test_validate_fee_params_management_too_high() {
        let result = validate_fee_params(600, 2000, 500); // 6% > 5% limit
        assert!(result.is_err(), "High management fee should fail");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'Mgmt fee too high', "Wrong error message");
    }

    #[test]
    fn test_validate_fee_params_performance_too_high() {
        let result = validate_fee_params(200, 6000, 500); // 60% > 50% limit
        assert!(result.is_err(), "High performance fee should fail");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'Perf fee too high', "Wrong error message");
    }

    #[test]
    fn test_validate_fee_params_reward_too_high() {
        let result = validate_fee_params(200, 2000, 2500); // 25% > 20% limit
        assert!(result.is_err(), "High reward fee should fail");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'Reward fee too high', "Wrong error message");
    }

    #[test]
    fn test_set_fee_params_success() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        let mut fee_config = get_default_fee_config(treasury, 1000000_u64);
        
        let result = set_fee_params(
            fee_config, 
            access_control,
            300,  // 3% management
            2500, // 25% performance  
            800,  // 8% reward
            owner,
            1000100_u64
        );
        
        assert!(result.is_ok(), "Owner should be able to set fee params");
        fee_config = result.unwrap();
        
        assert!(fee_config.management_fee_bps == 300, "Management fee should be updated");
        assert!(fee_config.performance_fee_bps == 2500, "Performance fee should be updated");
        assert!(fee_config.reward_fee_bps == 800, "Reward fee should be updated");
        assert!(fee_config.last_fee_timestamp == 1000100, "Fee timestamp should be reset");
    }

    #[test]
    fn test_rescue_token_success() {
        let (owner, treasury, keeper, _) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let token = starknet::contract_address_const::<0x999>();
        let to = starknet::contract_address_const::<0x888>();
        let amount = 1000_u256;
        let current_timestamp = 1000000_u64;
        
        let result = rescue_token(access_control, token, to, amount, owner, current_timestamp);
        assert!(result.is_ok(), "Owner should be able to rescue tokens");
        
        let event = result.unwrap();
        assert!(event.token == token, "Event should show correct token");
        assert!(event.to == to, "Event should show correct recipient");
        assert!(event.amount == amount, "Event should show correct amount");
        assert!(event.rescued_by == owner, "Event should show correct rescuer");
    }

    #[test]
    fn test_rescue_token_unauthorized() {
        let (owner, treasury, keeper, user) = get_test_addresses();
        let access_control = get_default_access_control(owner, treasury, keeper);
        
        let token = starknet::contract_address_const::<0x999>();
        let to = starknet::contract_address_const::<0x888>();
        let amount = 1000_u256;
        
        let result = rescue_token(access_control, token, to, amount, user, 1000000_u64);
        assert!(result.is_err(), "User should not be able to rescue tokens");
        let error: felt252 = result.unwrap_err();
        assert!(error == 'AccessControl: not owner', "Wrong error message");
    }
}