use starknet::ContractAddress;

pub trait ILendMod<TStruct, TToken> {
    fn deposit(self: TStruct, token: ContractAddress, amount: u256) -> u256;
    fn withdraw(self: TStruct, token: ContractAddress, amount: u256) -> u256;
    fn borrow(self: TStruct, token: ContractAddress, amount: u256) -> u256;
    fn repay(self: TStruct, token: ContractAddress, amount: u256) -> u256;
    fn health_factor(self: @TStruct, user: ContractAddress, deposits: Array<TToken>, borrows: Array<TToken>) -> u32;
    fn borrow_amount(self: @TStruct, token: ContractAddress, user: ContractAddress) -> u256;
    fn assert_valid(self: @TStruct);
    fn max_borrow_amount(self: @TStruct, deposit_token: TToken, deposit_amount: u256, borrow_token: TToken, min_hf: u32) -> u256;
    fn min_borrow_required(self: @TStruct, token: ContractAddress) -> u256;
    fn get_repay_amount(self: @TStruct, token: ContractAddress, amount: u256) -> u256;
    fn deposit_amount(self: @TStruct, asset: ContractAddress, user: ContractAddress) -> u256;
}

