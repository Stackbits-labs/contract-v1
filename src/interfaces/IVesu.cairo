use starknet::ContractAddress;

// TODO: Update with actual Vesu Protocol ABI once available
// Current implementation uses placeholder interface based on common lending protocol patterns

#[starknet::interface]
pub trait IVesu<TContractState> {
    // Supply/Deposit Functions
    /// @notice Supplies assets to Vesu protocol and receives vTokens
    /// @param asset The address of the underlying asset (e.g., wBTC)
    /// @param amount The amount of assets to supply
    /// @return The amount of vTokens minted
    fn supply(ref self: TContractState, asset: ContractAddress, amount: u256) -> u256;
    
    /// @notice Alternative deposit function (some protocols use this naming)
    /// @param asset The address of the underlying asset
    /// @param amount The amount of assets to deposit
    /// @param receiver The address to receive vTokens
    /// @return The amount of vTokens minted
    fn deposit(ref self: TContractState, asset: ContractAddress, amount: u256, receiver: ContractAddress) -> u256;

    // Withdraw/Redeem Functions
    /// @notice Redeems vTokens for underlying assets
    /// @param asset The address of the underlying asset
    /// @param amount The amount of assets to redeem
    /// @return The actual amount of assets received
    fn redeem(ref self: TContractState, asset: ContractAddress, amount: u256) -> u256;
    
    /// @notice Withdraws a specific amount of underlying assets
    /// @param asset The address of the underlying asset
    /// @param amount The amount of assets to withdraw
    /// @param receiver The address to receive the assets
    /// @return The amount of vTokens burned
    fn withdraw(ref self: TContractState, asset: ContractAddress, amount: u256, receiver: ContractAddress) -> u256;

    // View Functions
    /// @notice Get the exchange rate from vToken to underlying asset
    /// @param asset The address of the underlying asset
    /// @return The exchange rate (scaled by 1e18)
    fn get_exchange_rate(self: @TContractState, asset: ContractAddress) -> u256;
    
    /// @notice Get the vToken balance of an account
    /// @param asset The address of the underlying asset
    /// @param account The account to check balance for
    /// @return The vToken balance
    fn balance_of_vtoken(self: @TContractState, asset: ContractAddress, account: ContractAddress) -> u256;
    
    /// @notice Get the underlying asset balance equivalent of vToken balance
    /// @param asset The address of the underlying asset
    /// @param account The account to check balance for
    /// @return The underlying asset equivalent
    fn balance_of_underlying(self: @TContractState, asset: ContractAddress, account: ContractAddress) -> u256;
    
    /// @notice Get the total supply of vTokens for an asset
    /// @param asset The address of the underlying asset
    /// @return The total vToken supply
    fn total_supply_vtoken(self: @TContractState, asset: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IERC20<TContractState> {
    // Basic ERC20 functions needed for vToken operations
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
}

// Events for Vesu operations
#[derive(Drop, starknet::Event)]
pub struct VesuSupply {
    pub asset: ContractAddress,
    pub supplier: ContractAddress, 
    pub amount: u256,
    pub vtokens_minted: u256,
}

#[derive(Drop, starknet::Event)]
pub struct VesuRedeem {
    pub asset: ContractAddress,
    pub redeemer: ContractAddress,
    pub amount: u256,
    pub vtokens_burned: u256,
}

// Vesu Protocol specific constants
pub mod vesu_constants {
    // TODO: Update with actual Vesu protocol addresses and constants
    pub const VESU_PROTOCOL_ADDRESS: felt252 = 0x1; // Placeholder
    pub const WBTC_VTOKEN_ADDRESS: felt252 = 0x2; // Placeholder for wBTC vToken
    pub const EXCHANGE_RATE_DECIMALS: u256 = 1000000000000000000; // 1e18
}