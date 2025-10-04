# StackBits Vault - Cairo 2.x Project

A modular vault system built with Cairo 2.x for Starknet.

## Project Structure

```
├── src/
│   ├── lib.cairo           # Main library entry point
│   ├── vault.cairo         # Vault core functionality
│   ├── strategy.cairo      # Investment strategies
│   ├── interfaces.cairo    # Contract interfaces
│   └── utils.cairo        # Utility functions
├── tests/
│   └── test_contract.cairo # Unit tests
├── scripts/
│   ├── deploy.sh          # Deployment script using starkli
│   └── setup.sh          # Environment setup script
├── .github/workflows/
│   └── ci.yml            # GitHub Actions CI/CD
├── Scarb.toml            # Project configuration
└── snfoundry.toml        # Starknet Foundry configuration
```

## Getting Started

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) - Cairo package manager
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) - Testing framework
- [starkli](https://github.com/xJonathanLEI/starkli) - CLI tool for deployment

### Building

```bash
# Build the project
scarb build

# Build release version
scarb build --profile release
```

### Testing

```bash
# Run all tests
scarb test
```

### Deployment

1. Setup environment:
```bash
./scripts/setup.sh
```

2. Configure your `.env` file with account details

3. Deploy contracts:
```bash
./scripts/deploy.sh sepolia stackbits_vault
```

## Modules

### Vault (`src/vault.cairo`)
Core vault functionality for asset management.

### Strategy (`src/strategy.cairo`) 
Investment strategy implementations.

### Interfaces (`src/interfaces.cairo`)
- **ISnip22Vault** - SNIP-22 (ERC-4626-like) compliant vault interface with full deposit/withdraw/mint/redeem functionality
- **IVault** - Legacy vault interface for backwards compatibility  
- **IStrategy** - Strategy contract interface for investment management

### Utils (`src/utils.cairo`)
Utility functions including math operations and constants.

## SNIP-22 Interface Features

The `ISnip22Vault` interface provides ERC-4626 compatible functionality:

**View Functions:**
- `total_assets()` - Total assets under management
- `convert_to_shares(assets)` / `convert_to_assets(shares)` - Conversion functions
- `preview_deposit/mint/withdraw/redeem()` - Preview exact amounts for operations
- `max_deposit/mint/withdraw/redeem()` - Maximum operation limits

**External Functions:**
- `deposit(assets, receiver)` - Deposit assets, receive shares
- `mint(shares, receiver)` - Mint specific shares amount  
- `withdraw(assets, receiver, owner)` - Withdraw specific assets amount
- `redeem(shares, receiver, owner)` - Redeem shares for assets

**Events:**
- `Deposit(user, receiver, assets, shares)` - Emitted on deposits/mints
- `Withdraw(user, receiver, owner, assets, shares)` - Emitted on withdrawals/redeems

## CI/CD

The project includes GitHub Actions workflow that:
- Builds the project on push/PR
- Runs all tests
- Creates release artifacts
- Supports both development and release builds

## License

This project is licensed under the MIT License.