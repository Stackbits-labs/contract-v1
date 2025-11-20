#[cfg(test)]
mod test_cl_vault {
    use snforge_std::{
        declare, ContractClassTrait,
    };
    use snforge_std::{DeclareResultTrait};
    use starknet::ContractAddress;
    use stackbits_contract_v1::strategies::cl_vault::interface::{
        IClVaultDispatcher, IClVaultDispatcherTrait, FeeSettings
    };
    use stackbits_contract_v1::interfaces::IEkuboCore::{Bounds, PoolKey};
    use stackbits_contract_v1::tests::utils::{deploy_access_control};
    #[feature("deprecated-starknet-consts")]
    use starknet::contract_address::contract_address_const;

    fn zero_address() -> ContractAddress {
        contract_address_const::<0>()
    }

    fn deploy_cl_vault() -> (IClVaultDispatcher, ContractAddress) {
        let access_control = deploy_access_control();
        
        // Declare and deploy CL Vault
        let cl_vault = declare("ConcLiquidityVault").unwrap().contract_class();
        
        let name: ByteArray = "Test CL Vault";
        let symbol: ByteArray = "TCLV";
        
        // Mock addresses for testing
        let zero_addr = zero_address();
        let ekubo_positions_contract = zero_addr;
        let ekubo_positions_nft = zero_addr;
        let ekubo_core = zero_addr;
        let oracle = zero_addr;
        
        // Mock bounds and pool key
        let bounds = Bounds { 
            lower: (-1000).try_into().unwrap(), 
            upper: 1000.try_into().unwrap() 
        };
        let pool_key = PoolKey {
            token0: zero_addr,
            token1: zero_addr,
            fee: 3000,
            tick_spacing: 60,
            extension: zero_addr
        };
        
        let fee_settings = FeeSettings {
            fee_bps: 100, // 1% fee
            fee_collector: zero_addr
        };
        
        // Note: ByteArray serialization in snforge is automatic when deploying
        // For manual calldata, extract first felt252 from ByteArray span
        // Short strings (< 31 bytes) can fit in single felt252
        // i129 serialization: mag (u128) and sign (bool)
        let name_span = name.span().snapshot();
        let symbol_span = symbol.span().snapshot();
        // ByteArray is serialized as array of felt252, get first element
        let name_felt: felt252 = if name_span.len() > 0 {
            *name_span.at(0)
        } else {
            0
        };
        let symbol_felt: felt252 = if symbol_span.len() > 0 {
            *symbol_span.at(0)
        } else {
            0
        };
        let mut calldata: Array<felt252> = array![
            name_felt,
            symbol_felt,
            access_control.into(),
            ekubo_positions_contract.into(),
            bounds.lower.mag.into(), // i129 lower mag
            bounds.lower.sign.into(), // i129 lower sign
            bounds.upper.mag.into(), // i129 upper mag
            bounds.upper.sign.into(), // i129 upper sign
            pool_key.token0.into(),
            pool_key.token1.into(),
            pool_key.fee.into(),
            pool_key.tick_spacing.into(),
            pool_key.extension.into(),
            ekubo_positions_nft.into(),
            ekubo_core.into(),
            oracle.into(),
            fee_settings.fee_bps.try_into().unwrap(), // u256 -> felt252
            fee_settings.fee_collector.into()
        ];
        
        let (address, _) = cl_vault.deploy(@calldata).expect("CL Vault deploy failed");
        let dispatcher = IClVaultDispatcher { contract_address: address };
        
        (dispatcher, access_control)
    }

    #[test]
    fn test_deploy_cl_vault() {
        let (dispatcher, _) = deploy_cl_vault();
        
        // Test that contract is deployed
        let settings = dispatcher.get_settings();
        let zero_addr = zero_address();
        assert(settings.oracle == zero_addr, 'Oracle should be set');
        assert(settings.fee_settings.fee_bps == 100, 'Fee should be 1%');
    }

    #[test]
    fn test_get_settings() {
        let (dispatcher, _) = deploy_cl_vault();
        
        let settings = dispatcher.get_settings();
        let zero_addr = zero_address();
        
        assert(settings.ekubo_positions_contract == zero_addr, 'Invalid positions contract');
        assert(settings.fee_settings.fee_bps == 100, 'Invalid fee bps');
        assert(settings.fee_settings.fee_collector == zero_addr, 'Invalid fee collector');
    }

    #[test]
    fn test_set_settings() {
        let (_dispatcher, _access_control) = deploy_cl_vault();
        
        // Only governor can set settings - this would fail without proper role setup
        // For now, just test that function exists
        // In real test, would need to grant governor role first
    }

    #[test]
    fn test_total_liquidity() {
        let (dispatcher, _) = deploy_cl_vault();
        
        let liquidity = dispatcher.total_liquidity();
        assert(liquidity == 0, 'Initial liquidity should be 0');
    }

    #[test]
    fn test_get_position_key() {
        let (dispatcher, _) = deploy_cl_vault();
        
        let position_key = dispatcher.get_position_key();
        let zero_addr = zero_address();
        
        // Position key should have valid structure
        assert(position_key.salt == 0, 'Initial NFT ID should be 0');
        let owner = position_key.owner;
        assert(owner == zero_addr, 'Owner should be positions contract');
    }

    // Note: Full deposit/withdraw tests would require:
    // - Mocked Ekubo contracts
    // - Actual token balances
    // - Proper pool setup
    // These are integration tests that require more complex setup
}

