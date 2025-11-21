# Vesu Rebalance Strategy
# Vesu Rebalance Strategy

## Overview

`VesuRebalance` is a strategy contract that optimizes yield across multiple Vesu pools. It acts as an ERC-4626-style vault that holds a base asset, deposits into multiple Vesu vTokens, and performs rebalances (deposit/withdraw) to improve overall yield while enforcing governance limits and collecting protocol fees.

This README mirrors the structure used in the repository README and documents public interface, constructor parameters, storage, flows, testing and deployment notes.

---

## Refactored Structure Overview

The contract and its modules are organized with clear separation of concerns:

```
📋 INTERFACES SECTION
├── IVesu - Vesu protocol interface
├── IERC4626 - ERC4626 vault interface
└── IAccessControl - Roles and access checks

🏗️ MAIN CONTRACT
├── 👑 Access control & admin
├── ⚙️ Vault configuration (allowed pools, settings)
├── 🪙 ERC4626 token logic (shares, mint/burn)
├── 📈 Rebalance & yield logic
├── 👥 Pool & holder helpers
└── Events & constructor

🔧 INTERNAL IMPLEMENTATIONS
├── VaultInternalImpl    → deposit/withdraw flow, interaction with Vesu
├── RebalanceInternalImpl→ rebalance loop, action execution
└── FeeInternalImpl      → fee collection & distribution helpers
```

---

## Key Improvements and Responsibilities

- Clear separation between external interface, internal implementations and helpers.
- Modular internal functions make unit testing and audits easier.
- Constructor accepts a `vesu_settings` struct so Vesu singleton / pool id / oracle are injected at deploy-time (no hard-coded addresses).

---

## Public Interface (summary)

- `constructor(name, symbol, asset, access_control, allowed_pools, settings, vesu_settings)`
- `deposit(assets)` — deposits base asset and mints shares
- `withdraw(shares)` — withdraws underlying assets proportionally
- `rebalance(actions)` — performs a sequence of deposit/withdraw actions (Relayer role)
- `rebalance_weights(actions)` — adjust pool weights according to governance
- `get_allowed_pools()` / `get_settings()` / `get_previous_index()` — getters
- `emergency_withdraw()` / `emergency_withdraw_pool(i)` — emergency ops

---

## Storage Organization

### Admin / Access
- `access_control`: ContractAddress (AccessControl contract)
- Roles: Governor, Relayer, Emergency Actor, Super admin

### Vault Configuration
- `asset`: ContractAddress (base asset)
- `allowed_pools`: list of `PoolProps` (pool_id, max_weight, v_token)
- `settings`: `Settings` struct (fee_bps, default_pool_index, fee_receiver)

### Vesu Settings
- `vesu_settings`: `vesuStruct` with fields:
   - `singleton`: `IStonDispatcher` (Vesu singleton dispatcher)
   - `pool_id`: felt252
   - `debt`: ContractAddress
   - `col`: ContractAddress
   - `oracle`: ContractAddress (must implement `IPriceOracleDispatcher.get_price`)

### Runtime State
- `previous_index`: u128 (index used for fee calc)
- `is_incentives_on`: bool
- `allowed_pools` storage (list)

---

## Function Flows (examples)

### Deposit Flow

1. `deposit(assets)` → checks not paused, collects fees
2. Approve asset to target vToken and deposit into default pool
3. Mint shares to depositor
4. Update pool storage and `previous_index`

### Rebalance Flow

1. `rebalance(actions)` requires Relayer role
2. Collect fees and compute yield before
3. Loop through `actions` and execute deposit/withdraw using vToken dispatchers
4. Compute yield after and assert yield increased
5. Emit `Rebalance` event

### Emergency Withdraw

1. `emergency_withdraw()` requires Emergency Actor
2. Loop over allowed pools and call `withdraw(max)` on each vToken
3. Transfer underlying asset to vault/recipient

---

## vesu_settings.oracle — important note

- The `oracle` value inside `vesu_settings` is not required to be the constant in `src/helpers/constants.cairo`, but it must be a contract deployed on the same network that implements the `IPriceOracleDispatcher` interface used by this code (`get_price(token)`).
- Tests in this repository use the constant `constants::Oracle()` (mainnet fork). If you plan to deploy on testnet or a local fork, provide an oracle address valid on that network.

---

## Example constructor arguments (JSON snippet)

```json
{
   "name": "Test Vesu Vault",
   "symbol": "tVSV",
   "asset": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
   "access_control": "0x...",
   "allowed_pools": [],
   "settings": { "fee_bps": 30, "default_pool_index": 0, "fee_receiver": "0x..." },
   "vesu_settings": {
      "singleton": { "contract_address": "0x2545b2e5d519fc230e9cd781046d3a64e092114f07e44771e0d719d148725ef" },
      "pool_id": "0x04dc4f0ca6ea4961e4c8373265bfd5317678f4fe374d76f3fd7135f57763bf28",
      "debt": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
      "col": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
      "oracle": "0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a"
   }
}
```

Note: adjust addresses according to the target network. The `pool_id` here matches the genesis pool constant used in the repo's `constants.cairo`.

---

## Testing

- Unit tests for the Vesu component live in `src/strategies/vesu_rebalance/test.cairo` and use `#[fork("mainnet_971311")]` to fork mainnet state. Tests rely on constants from `src/helpers/constants.cairo`.
- When running tests locally, ensure your snforge/sncast configuration points to a compatible RPC.

---

## Deploy guidance

1. Build:

```bash
scarb build
```

2. Declare contract`.

```bash
sncast --account=stackbits declare \
    --contract-name=AccessControl \
    --network=sepolia

sncast --account=stackbits declare \
    --contract-name=VesuRebalance \
    --network=sepolia
```

3. Deploy using a funded, deployed account and a compatible RPC profile.

---

## Deployment checklist (fill after declare/deploy)

After you run `sncast declare` and `sncast deploy` (or when a class is pre-declared), record the resulting class hashes and deployed addresses here for repeatable deployments and future upgrades.

- AccessControl
   - Deployed address: "0x0260f35e6c5cafb124ed59f118de1bc9d726a0c27fd3cce692650495b43bedcc"

- VesuRebalance
   - Deployed address: "0x05e462461553fe3787d29e95353ca6d68631073567a6621ce6806f53584bf359"


## Security & Access Control (summary)

- Role-guarded functions for protocol safety.
- Fee collection uses `previous_index` pattern to compute accrued fees.
- Critical admin calls restricted to Governor / Super admin.

---

## References

- Contract: `src/strategies/vesu_rebalance/vesu_rebalance.cairo`
- Interface: `src/strategies/vesu_rebalance/interface.cairo`
- Tests: `src/strategies/vesu_rebalance/test.cairo`
- Constants: `src/helpers/constants.cairo`

If you want this README translated to Vietnamese or want me to also update `deploy_vesu_args.json` with the constants values from `src/helpers/constants.cairo`, tell me and I will apply those changes on branch `kaito`.
