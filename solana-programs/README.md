## Safe Harbor Registry (Solana)

Solana/Anchor implementation of Safe Harbor Registry V2 with near-complete feature parity to the EVM version and Solana-specific optimizations.

### Requirements
- Rust 1.70+
- Solana CLI 1.18+
- Anchor CLI 0.31+
- Node.js 18+

### Install / Build
```bash
npm install
anchor build
```

### Quick Start (Localnet)
```bash
# Deploy registry and set supported chains
npm run deploy

# Create and adopt an agreement
npm run adopt agreement-data-sample.json

# Query agreement details
npm run query <agreement-address>
```

### Devnet
```bash
export ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
export ANCHOR_WALLET=./owner-keypair.json
npm run deploy
```

### Scripts
- deploy — initialize registry and set chains
- adopt [file] [ownerPubkey?] — create (+adopt) from JSON (see agreement-data-sample.json)
- adopt-existing <agreement> — adopt an existing agreement for the current wallet
- query <agreement> — print agreement details (uses adopter-keyed PDA for adoption status)

### Program ID
If you change the program ID, update it in `programs/safe_harbor/src/lib.rs` and `Anchor.toml`.

## EVM Parity and Key Differences

### Owner Specification
- EVM: Owner is `msg.sender` by default.
- Solana: Pass an explicit `owner: Pubkey` while the deployer signs. Owner can be any address. Owner-requiring accounts are `UncheckedAccount` unless a signature is required.

### Transaction Sizing
- EVM: Limited by gas.
- Solana: Hard tx size limit (~1232 bytes).
- Strategy selection:
  - ≤1 chain AND ≤5 accounts → single transaction
  - Otherwise → progressive creation (multiple transactions), requires owner keypair (not just owner address)

### Storage & Accounts
- EVM: Dynamic storage in contract state.
- Solana: PDA accounts with explicit sizing and safe resizing; rent considerations apply.

### API Equivalents (EVM → Solana)
- Registry chains: `registry.setValidChains(chainIds)` → `program.methods.setValidChains(chainIds).rpc()`
- Create agreement: `factory.createAgreement(params)` → `program.methods.createAgreement(params, owner).rpc()`
- Create+adopt: `factory.createAndAdopt(params)` → `program.methods.createAndAdoptAgreement(params, owner).rpc()`
- Adopt: `registry.adoptSafeHarborV2(addr)` → `program.methods.adoptSafeHarbor(addr).rpc()`

## Core Instructions
- `initialize_registry(owner: Pubkey)`
- `set_valid_chains(chains: Vec<String>)`
- `create_agreement(params: AgreementInitParams, owner: Pubkey)`
- `create_and_adopt_agreement(params: AgreementInitParams, owner: Pubkey)`
- `adopt_safe_harbor(agreement: Pubkey)`
- `get_agreement_for_adopter()` — preferred O(1) lookup using adopter-keyed PDA
- `add_chains(chains: Vec<Chain>)` (owner only)
- `add_accounts(caip2_chain_id: String, accounts: Vec<AccountInScope>)` (owner only)

## Data
- Minimal schema: see `agreement-data-sample.json`.
- Chains use CAIP-2 IDs (e.g., `eip155:1`). Registry must approve chains.

## Testing
```bash
anchor test        # integration
(cd programs/safe_harbor && cargo test --lib)  # unit
```

## Tips
- Keep strings short; put details off-chain (URI) to reduce tx size.
- For large agreements, use owner keypair; optionally set `PREFUND_AGREEMENT_SOL`.
- Enable logs with `export ANCHOR_LOG=true`.

### Deprecations
- `get_agreement(adopter)` is deprecated and may not reflect current adoption. Use `get_agreement_for_adopter()` or derive/fetch the `AdoptionHead` PDA `["adoption_head", adopter]`.

## Quick Commands
```bash
# Create simple agreement for a custom owner (single tx)
npm run adopt test-simple.json <ownerPubkey>

# Create complex agreement (progressive; requires owner keypair)
npm run adopt agreement-data-sample.json

# Query agreement
npm run query <agreement-address>
```


