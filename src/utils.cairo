// Utils module - Utility functions and helpers

// Constants used throughout the vault system
pub const MAX_BPS: u16 = 10000; // 100% in basis points
pub const MIN_DEPOSIT: u256 = 1000; // Minimum deposit amount
pub const FEE_DENOMINATOR: u256 = 10000; // Fee calculation denominator

// Math utilities
/// Calculate percentage of a value
pub fn calculate_percentage(value: u256, percentage: u16) -> u256 {
    if percentage == 0 {
        return 0;
    }
    (value * percentage.into()) / 100
}

/// Safe addition with overflow check
pub fn safe_add(a: u256, b: u256) -> Option<u256> {
    let result = a + b;
    if result < a {
        Option::None
    } else {
        Option::Some(result)
    }
}