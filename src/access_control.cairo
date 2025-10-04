// AccessControl - Comprehensive access control system for VaultSwBTC
use starknet::ContractAddress;

// Access Control Roles and State
#[derive(Copy, Drop, starknet::Store)]
pub struct AccessControlState {
    pub owner: ContractAddress,           // Multisig owner with highest privileges
    pub pending_owner: ContractAddress,   // Pending owner for two-step ownership transfer
    pub treasury: ContractAddress,        // Treasury address for fee collection
    pub keeper: ContractAddress,          // Keeper for harvest operations
    pub paused: bool,                    // Emergency pause state
    pub reentrancy_guard: bool,          // Reentrancy protection flag
}

// Role identifiers for events and validation
pub mod roles {
    pub const OWNER: felt252 = 'OWNER';
    pub const KEEPER: felt252 = 'KEEPER'; 
    pub const TREASURY: felt252 = 'TREASURY';
}

// Emergency pause functionality
#[derive(Copy, Drop, starknet::Store)]
pub struct PauseState {
    pub paused: bool,
    pub pause_timestamp: u64,
    pub paused_by: ContractAddress,
}

// Events for access control operations
#[derive(Drop, starknet::Event)]
pub struct OwnershipTransferInitiated {
    #[key]
    pub previous_owner: ContractAddress,
    #[key] 
    pub new_owner: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct OwnershipTransferred {
    #[key]
    pub previous_owner: ContractAddress,
    #[key]
    pub new_owner: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RoleUpdated {
    #[key]
    pub role: felt252,
    #[key]
    pub account: ContractAddress,
    #[key]
    pub granted_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Paused {
    #[key]
    pub paused_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Unpaused {
    #[key]
    pub unpaused_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyTokenRescue {
    #[key]
    pub token: ContractAddress,
    #[key]
    pub to: ContractAddress,
    #[key]
    pub rescued_by: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

// Access control functions
pub fn get_default_access_control(owner: ContractAddress, treasury: ContractAddress, keeper: ContractAddress) -> AccessControlState {
    AccessControlState {
        owner,
        pending_owner: starknet::contract_address_const::<0>(), // Zero address indicates no pending transfer
        treasury,
        keeper,
        paused: false,
        reentrancy_guard: false,
    }
}

// Modifiers and validation functions
pub fn only_owner(state: AccessControlState, caller: ContractAddress) -> Result<(), felt252> {
    if caller != state.owner {
        return Err('AccessControl: not owner');
    }
    Ok(())
}

pub fn only_keeper(state: AccessControlState, caller: ContractAddress) -> Result<(), felt252> {
    if caller != state.keeper && caller != state.owner {
        return Err('AccessControl: not keeper');
    }
    Ok(())
}

pub fn only_treasury(state: AccessControlState, caller: ContractAddress) -> Result<(), felt252> {
    if caller != state.treasury && caller != state.owner {
        return Err('AccessControl: not treasury');
    }
    Ok(())
}

pub fn when_not_paused(state: AccessControlState) -> Result<(), felt252> {
    if state.paused {
        return Err('AccessControl: paused');
    }
    Ok(())
}

pub fn when_paused(state: AccessControlState) -> Result<(), felt252> {
    if !state.paused {
        return Err('AccessControl: not paused');
    }
    Ok(())
}

// Reentrancy Guard implementation
pub fn nonreentrant_start(mut state: AccessControlState) -> Result<AccessControlState, felt252> {
    if state.reentrancy_guard {
        return Err('ReentrancyGuard: reentrant call');
    }
    state.reentrancy_guard = true;
    Ok(state)
}

pub fn nonreentrant_end(mut state: AccessControlState) -> AccessControlState {
    state.reentrancy_guard = false;
    state
}

// Two-step ownership transfer for security
pub fn transfer_ownership(
    mut state: AccessControlState, 
    new_owner: ContractAddress,
    caller: ContractAddress,
    current_timestamp: u64
) -> Result<(AccessControlState, OwnershipTransferInitiated), felt252> {
    only_owner(state, caller)?;
    
    if new_owner == starknet::contract_address_const::<0>() {
        return Err('AccessControl: zero address');
    }
    
    state.pending_owner = new_owner;
    
    let event = OwnershipTransferInitiated {
        previous_owner: state.owner,
        new_owner,
        timestamp: current_timestamp,
    };
    
    Ok((state, event))
}

pub fn accept_ownership(
    mut state: AccessControlState,
    caller: ContractAddress,
    current_timestamp: u64
) -> Result<(AccessControlState, OwnershipTransferred), felt252> {
    if caller != state.pending_owner {
        return Err('Not pending owner');
    }
    
    if state.pending_owner == starknet::contract_address_const::<0>() {
        return Err('No pending transfer');
    }
    
    let previous_owner = state.owner;
    state.owner = state.pending_owner;
    state.pending_owner = starknet::contract_address_const::<0>();
    
    let event = OwnershipTransferred {
        previous_owner,
        new_owner: state.owner,
        timestamp: current_timestamp,
    };
    
    Ok((state, event))
}

// Role management functions
pub fn set_keeper(
    mut state: AccessControlState,
    new_keeper: ContractAddress,
    caller: ContractAddress,
    current_timestamp: u64
) -> Result<(AccessControlState, RoleUpdated), felt252> {
    only_owner(state, caller)?;
    
    if new_keeper == starknet::contract_address_const::<0>() {
        return Err('AccessControl: zero address');
    }
    
    state.keeper = new_keeper;
    
    let event = RoleUpdated {
        role: roles::KEEPER,
        account: new_keeper,
        granted_by: caller,
        timestamp: current_timestamp,
    };
    
    Ok((state, event))
}

pub fn set_treasury(
    mut state: AccessControlState,
    new_treasury: ContractAddress,
    caller: ContractAddress,
    current_timestamp: u64
) -> Result<(AccessControlState, RoleUpdated), felt252> {
    only_owner(state, caller)?;
    
    if new_treasury == starknet::contract_address_const::<0>() {
        return Err('AccessControl: zero address');
    }
    
    state.treasury = new_treasury;
    
    let event = RoleUpdated {
        role: roles::TREASURY,
        account: new_treasury,
        granted_by: caller,
        timestamp: current_timestamp,
    };
    
    Ok((state, event))
}

// Emergency pause functions
pub fn pause(
    mut state: AccessControlState,
    caller: ContractAddress,
    current_timestamp: u64
) -> Result<(AccessControlState, Paused), felt252> {
    only_owner(state, caller)?;
    when_not_paused(state)?;
    
    state.paused = true;
    
    let event = Paused {
        paused_by: caller,
        timestamp: current_timestamp,
    };
    
    Ok((state, event))
}

pub fn unpause(
    mut state: AccessControlState,
    caller: ContractAddress,
    current_timestamp: u64
) -> Result<(AccessControlState, Unpaused), felt252> {
    only_owner(state, caller)?;
    when_paused(state)?;
    
    state.paused = false;
    
    let event = Unpaused {
        unpaused_by: caller,
        timestamp: current_timestamp,
    };
    
    Ok((state, event))
}

// Helper functions for role checks
pub fn has_role(state: AccessControlState, role: felt252, account: ContractAddress) -> bool {
    if role == roles::OWNER {
        account == state.owner
    } else if role == roles::KEEPER {
        account == state.keeper || account == state.owner
    } else if role == roles::TREASURY {
        account == state.treasury || account == state.owner
    } else {
        false
    }
}

pub fn is_owner(state: AccessControlState, account: ContractAddress) -> bool {
    account == state.owner
}

pub fn is_keeper(state: AccessControlState, account: ContractAddress) -> bool {
    account == state.keeper || account == state.owner
}

pub fn is_treasury(state: AccessControlState, account: ContractAddress) -> bool {
    account == state.treasury || account == state.owner
}

// Validation helpers for admin functions
pub fn validate_fee_params(management_fee_bps: u256, performance_fee_bps: u256, reward_fee_bps: u256) -> Result<(), felt252> {
    if management_fee_bps > 500 { // Max 5% management fee
        return Err('Mgmt fee too high');
    }
    
    if performance_fee_bps > 5000 { // Max 50% performance fee
        return Err('Perf fee too high');
    }
    
    if reward_fee_bps > 2000 { // Max 20% reward fee
        return Err('Reward fee too high');
    }
    
    Ok(())
}