#[cfg(test)]
mod test_vesu_integration {
    use stackbits_vault::interfaces::IVesu::{vesu_constants};
    use stackbits_vault::strategy::VesuAdapter::{
        VesuAdapterConfig, get_default_vesu_config
    };

    #[test]
    fn test_vesu_config_creation() {
        let config = get_default_vesu_config();
        assert!(config.is_active, "Config should be active by default");
    }

    #[test]
    fn test_vesu_constants() {
        // Verify constants are properly defined
        let expected: u256 = 1000000000000000000;
        assert!(vesu_constants::EXCHANGE_RATE_DECIMALS == expected, "Exchange rate decimals should be 1e18");
    }

    #[test]  
    fn test_vesu_adapter_config_structure() {
        // Test that we can create and access VesuAdapterConfig fields
        let config = VesuAdapterConfig {
            vesu_protocol: starknet::contract_address_const::<0x1>(),
            asset_token: starknet::contract_address_const::<0x2>(),
            vtoken_address: starknet::contract_address_const::<0x3>(),
            vault_address: starknet::contract_address_const::<0x4>(),
            owner: starknet::contract_address_const::<0x5>(),
            is_active: true,
        };
        
        assert!(config.is_active, "Config should be active");
    }
}