use starknet::ContractAddress;

#[starknet::interface]
pub trait IPriceOracle<TContractState> {
    fn get_price(self: @TContractState, token: ContractAddress) -> u256;
}

