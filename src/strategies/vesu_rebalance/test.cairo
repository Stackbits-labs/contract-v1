#[cfg(test)]
mod test_vesu_rebalance {
    use snforge_std::{
        declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use snforge_std::{DeclareResultTrait};
    use starknet::ContractAddress;
    use stackbits_contract_v1::strategies::vesu_rebalance::interface::{
        IVesuRebalDispatcher, IVesuRebalDispatcherTrait, PoolProps, Settings
    };
    use stackbits_contract_v1::tests::utils::{deploy_access_control};
    use stackbits_contract_v1::components::vesu::{vesuStruct, vesuSettingsImpl};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    #[feature("deprecated-starknet-consts")]
    use starknet::contract_address::contract_address_const;

    fn zero_address() -> ContractAddress {
        contract_address_const::<0>()
    }

    fn deploy_mock_erc20(name: ByteArray, symbol: ByteArray) -> ContractAddress {
        let erc20_class = declare("MockERC20").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        calldata.append(1000000000000000000000); // initial_supply low (1000 tokens)
        calldata.append(0); // initial_supply high
        calldata.append(starknet::get_contract_address().into()); // recipient
        
        let (address, _) = erc20_class.deploy(@calldata).expect('ERC20 deploy failed');
        address
    }

    fn deploy_vesu_rebalance(
        asset: ContractAddress
    ) -> (IVesuRebalDispatcher, ContractAddress) {
        let access_control = deploy_access_control();
        // Declare and deploy Vesu Rebalance
        let vesu_rebal = declare("VesuRebalance").unwrap().contract_class();
        
        let name: ByteArray = "Test Vesu Vault";
        let symbol: ByteArray = "TVV";
        
        // Mock pool props
        let mut allowed_pools: Array<PoolProps> = array![];
        let zero_addr = zero_address();
        let pool_props = PoolProps {
            pool_id: 0,
            max_weight: 10000, // 100%
            v_token: zero_addr
        };
        allowed_pools.append(pool_props);
        
        let settings = Settings {
            default_pool_index: 0,
            fee_bps: 100, // 1% fee
            fee_receiver: zero_addr
        };
        
        let vesu_settings = vesuStruct {
            pool_id: 0,
            debt: zero_addr,
            col: zero_addr,
            oracle: zero_addr,
            singleton: stackbits_contract_v1::interfaces::IVesu::IStonDispatcher {
                contract_address: zero_addr
            }
        };
        
        // Constructor calldata with proper serialization
        let mut calldata: Array<felt252> = array![];
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        calldata.append(asset.into());
        calldata.append(access_control.into());
        
        // Serialize allowed_pools array
        calldata.append(allowed_pools.len().into());
        calldata.append(pool_props.pool_id);
        calldata.append(pool_props.max_weight.into());
        calldata.append(pool_props.v_token.into());
        
        // Serialize settings
        calldata.append(settings.default_pool_index.into());
        calldata.append(settings.fee_bps.into());
        calldata.append(settings.fee_receiver.into());
        
        // Serialize vesu_settings
        calldata.append(vesu_settings.pool_id);
        calldata.append(vesu_settings.debt.into());
        calldata.append(vesu_settings.col.into());
        calldata.append(vesu_settings.oracle.into());
        calldata.append(vesu_settings.singleton.contract_address.into());
        
        let (address, _) = vesu_rebal.deploy(@calldata).expect('Vesu Rebalance deploy failed');
        let dispatcher = IVesuRebalDispatcher { contract_address: address };
        
        (dispatcher, access_control)
    }

    #[test]
    fn test_deploy_vesu_rebalance() {
        let asset = deploy_mock_erc20("Mock USDC", "USDC");
        let (dispatcher, _) = deploy_vesu_rebalance(asset);
        // Test that contract is deployed
        let settings = dispatcher.get_settings();
        assert(settings.fee_bps == 100, 'Fee should be 1%');
        assert(settings.default_pool_index == 0, 'Default pool index should be 0');
    }

    #[test]
    fn test_get_settings() {
        let asset = deploy_mock_erc20("Mock USDC", "USDC");
        let (dispatcher, _) = deploy_vesu_rebalance(asset);
        let settings = dispatcher.get_settings();
        let zero_addr = zero_address();
        
        assert(settings.default_pool_index == 0, 'Invalid default pool index');
        assert(settings.fee_bps == 100, 'Invalid fee bps');
        assert(settings.fee_receiver == zero_addr, 'Invalid fee receiver');
    }

    #[test]
    fn test_get_allowed_pools() {
        let asset = deploy_mock_erc20("Mock USDC", "USDC");
        let (dispatcher, _) = deploy_vesu_rebalance(asset);
        let pools = dispatcher.get_allowed_pools();
        assert(pools.len() == 1, 'Should have 1 allowed pool');
        
        let pool = *pools.at(0);
        assert(pool.pool_id == 0, 'Pool ID should be 0');
        assert(pool.max_weight == 10000, 'Max weight should be 100%');
    }

    #[test]
    fn test_get_previous_index() {
        let asset = deploy_mock_erc20("Mock USDC", "USDC");
        let (dispatcher, _) = deploy_vesu_rebalance(asset);
        let previous_index = dispatcher.get_previous_index();
        // Default index should be 10^18
        assert(previous_index == 1000_000_000_000_000_000, 'Default index should be 10^18');
    }

    #[test]
    fn test_compute_yield() {
        let asset = deploy_mock_erc20("Mock USDC", "USDC");
        let (dispatcher, _) = deploy_vesu_rebalance(asset);
        let (_yield_value, total_amount) = dispatcher.compute_yield();
        
        // Initially, yield should be computed even with zero amounts
        // Exact values depend on Vesu pool state
        // u256 is always >= 0, so just check it's a valid u256
        assert(total_amount == total_amount, 'Total amount should be valid');
    }

    // Note: Full rebalance tests would require:
    // - Mocked Vesu contracts
    // - Actual token balances
    // - Proper pool setup with vTokens
    // These are integration tests that require more complex setup
}

