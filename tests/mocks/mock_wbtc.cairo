use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockWBTC<TContractState> {
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn total_supply(self: @TContractState) -> u256;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MockWBTC {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address};

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        total_supply: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_supply: u256, recipient: ContractAddress) {
        self.total_supply.write(initial_supply);
        self.balances.write(recipient, initial_supply);
    }

    #[abi(embed_v0)]
    impl MockWBTCImpl of super::IMockWBTC<ContractState> {
        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((sender, caller));
            assert!(current_allowance >= amount, "Insufficient allowance");
            
            let sender_balance = self.balances.read(sender);
            assert!(sender_balance >= amount, "Insufficient balance");
            
            self.balances.write(sender, sender_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
            
            self.allowances.write((sender, caller), current_allowance - amount);
            true
        }
        
        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let caller_balance = self.balances.read(caller);
            assert!(caller_balance >= amount, "Insufficient balance");
            
            self.balances.write(caller, caller_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);
            true
        }
        
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
            true
        }
        
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            let current_supply = self.total_supply.read();
            self.total_supply.write(current_supply + amount);
            
            let current_balance = self.balances.read(to);
            self.balances.write(to, current_balance + amount);
        }
    }
}
