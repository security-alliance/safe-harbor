# Safe Harbor Registry - Solana Implementation

This repository contains the Solana/Anchor implementation of the Safe Harbor Registry V2 contracts, providing **complete feature parity** with the original Ethereum implementation while handling Solana-specific constraints.

## 🌟 Key Features

### EVM-Compatible Owner Specification
- **Custom Owner Addresses**: Specify any public key as agreement owner (matches EVM behavior)
- **Deployer vs Owner**: Deployer signs transactions, specified address becomes owner
- **No Owner Keypair Required**: Create agreements for any address without their private key

### Smart Transaction Size Management
- **Automatic Strategy Selection**: Single transaction for simple agreements, progressive creation for complex ones
- **Transaction Size Optimization**: Handles Solana's ~1232 byte transaction limit automatically
- **Progressive Creation**: Large agreements split across multiple transactions seamlessly

### Dynamic Storage & Unlimited Scalability
- **No Hardcoded Limits**: Unlimited chains, accounts, and agreements using dynamic account resizing
- **Complete V2 Parity**: All EVM V2 functionality including factory patterns and complex data structures
- **Optimized Architecture**: Uses PDAs, Anchor framework, and efficient account management

## 🏗️ Architecture

### Core Components

1. **Registry Account** - Central registry with dynamic storage for chains and agreement adoptions
2. **Agreement Account** - Individual agreements with unlimited chains and accounts  
3. **Progressive Creation System** - Handles transaction size limits through batching
4. **Owner Address Support** - EVM-like owner specification without requiring keypairs

### Transaction Strategies

The system automatically chooses between two strategies based on agreement complexity:

#### Standard Strategy (Single Transaction)
- **Used for**: Simple agreements (≤1 chain OR ≤5 accounts)
- **Benefits**: Immediate completion, lower cost
- **Supports**: Owner address-only mode

#### Progressive Strategy (Multiple Transactions)
- **Used for**: Complex agreements (>1 chain OR >5 accounts) 
- **Process**: 
  1. Create minimal agreement (no accounts)
  2. Add remaining chains in batches
  3. Add all accounts in batches
- **Requires**: Owner keypair for post-creation operations
- **Benefits**: Handles any agreement size

## 📏 Transaction Size: Constraints, Strategy, and Troubleshooting

### Hard Limit and Why It Matters
- Solana has a hard transaction size limit of ~1232 bytes (instruction data, account metas, signatures, Borsh overhead).
- Agreements include strings (names, URIs, diligence), multiple chains, and account lists; even 2 chains with 9 accounts can exceed the limit.

### Strategy Selection Matrix
```
≤1 chain AND ≤5 accounts → Standard (single tx)
>1 chain OR >5 accounts  → Progressive (multi-tx)
```
- Conservative thresholds account for string length and serialization overhead.

### Progressive Creation Phases
1) Initial creation: metadata + first chain (≤3), no accounts (resizes as needed)
2) Add remaining chains in batches (≈5/tx)
3) Add accounts per chain in batches (≈5/tx)

### Owner Modes and Limits
- Owner keypair mode: supports progressive flow, prefunding, and post-creation edits.
- Owner address-only mode: single-tx agreements only (no progressive/post-creation ops).

### Common Errors and Fixes
- Transaction too large: automatically switches to progressive; shorten strings if still failing.
- Encoding overruns Buffer: reduce long strings; progressive creation.
- Insufficient funds for rent: prefund via `PREFUND_AGREEMENT_SOL` and ensure owner wallet has SOL.

### Optimization Tips
- Minimize string sizes (put details off-chain; use URI).
- Group accounts under fewer chains when possible.
- For large protocols, plan progressive creation and set `PREFUND_AGREEMENT_SOL`.

### Debugging Tools
- `export ANCHOR_LOG=true` for verbose logs during scripts.
- Estimate data size (`wc -c agreement-data.json`) to anticipate progressive creation.
- Inspect failed tx in Solana Explorer for size-related errors.

## 📦 Installation & Setup

### Prerequisites
- Rust 1.70+
- Solana CLI 1.18+
- Anchor CLI 0.31+
- Node.js 18+

### Installation
```bash
# Install dependencies
npm install

# Build the program
anchor build

# Run tests
anchor test
```

### Environment Setup
```bash
# Solana network configuration
export ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
export ANCHOR_WALLET=~/.config/solana/id.json

# Optional: Agreement owner (provide either keypair path OR address)
export OWNER_KEYPAIR_PATH=./owner-keypair.json  # Traditional mode
export OWNER_ADDRESS=dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB  # Address-only mode

# Optional: Agreement creation settings
export AGREEMENT_DATA_PATH=./agreement-data.json
export SHOULD_ADOPT=true
export PREFUND_AGREEMENT_SOL=1.0  # For large agreements
```

## 🚀 Usage

### Method 1: NPM Scripts (Recommended)
```bash
# Deploy registry and set valid chains
npm run deploy

# Create and adopt agreement (auto-detects strategy)
npm run adopt [agreement-file.json] [owner-address]

# Query agreement details
npm run query [agreement-address]
```

### Method 2: Direct Script Execution
```bash
# Deploy registry
npx ts-node scripts/deploy-and-set-chains.ts

# Create agreement with owner keypair (supports any size)
npx ts-node scripts/adopt-agreement.ts my-protocol.json

# Create agreement with owner address (simple agreements only)
npx ts-node scripts/adopt-agreement.ts my-protocol.json dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB

# Query agreement details
npx ts-node scripts/get-agreement-details.ts <agreement-address>
```

## 👤 Owner Modes

### Owner Keypair Mode (Full Features)
**Setup**: Provide `OWNER_KEYPAIR_PATH` or let script generate one
```bash
export OWNER_KEYPAIR_PATH=./my-owner.json
npx ts-node scripts/adopt-agreement.ts my-protocol.json
```

**Capabilities**:
- ✅ Create simple agreements (single transaction)
- ✅ Create large agreements (progressive strategy)
- ✅ Prefund agreements for rent
- ✅ Post-creation operations (add chains, accounts)

### Owner Address Mode (EVM-like)
**Setup**: Provide `OWNER_ADDRESS` or pass as argument
```bash
# Via environment variable
export OWNER_ADDRESS=dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB
npx ts-node scripts/adopt-agreement.ts my-protocol.json

# Via command line argument
npx ts-node scripts/adopt-agreement.ts my-protocol.json dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB
```

**Capabilities**:
- ✅ Create simple agreements (single transaction)
- ❌ Create large agreements (requires progressive creation with owner signatures)
- ❌ Prefund agreements (requires owner to sign transfers)
- ❌ Post-creation operations (require owner signature)

**Use Cases**:
- Protocols creating agreements for their official address
- Service providers creating agreements on behalf of clients
- Multi-sig scenarios where creation and ownership are separate

## 📊 Agreement Complexity & Strategy Selection

The system automatically detects agreement complexity and selects the optimal strategy:

### Simple Agreements → Standard Strategy
**Criteria**: ≤1 chain AND ≤5 accounts
**Examples**:
```json
{
  "chains": [
    {
      "id": "eip155:1",
      "accounts": [
        {"accountAddress": "0x1234...", "childContractScope": 0}
      ]
    }
  ]
}
```
**Result**: Single transaction, works with owner address-only mode

### Complex Agreements → Progressive Strategy  
**Criteria**: >1 chain OR >5 accounts
**Examples**:
```json
{
  "chains": [
    {"id": "eip155:1", "accounts": [/* 8 accounts */]},
    {"id": "eip155:137", "accounts": [/* 1 account */]}
  ]
}
```
**Result**: Multiple transactions, requires owner keypair

### Why These Limits?
Solana has a **strict transaction size limit (~1232 bytes)**. Even seemingly small agreements can exceed this due to:
- String data (protocol names, URIs, diligence requirements)
- Serialization overhead (Borsh encoding metadata)
- Account structures (each account has multiple fields)

## 📋 Agreement Data Format

Create your `agreement-data.json`:

```json
{
  "protocolName": "MyDeFi Protocol",
  "agreementURI": "https://myprotocol.com/security-policy",
  "chains": [
    {
      "id": "eip155:1",
      "assetRecoveryAddress": "0x1234567890123456789012345678901234567890",
      "accounts": [
        {
          "accountAddress": "0x1234567890123456789012345678901234567890",
          "childContractScope": 0  // 0=None, 1=ExistingOnly, 2=All, 3=FutureOnly
        },
        {
          "accountAddress": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
          "childContractScope": 1
        }
      ]
    },
    {
      "id": "eip155:137",
      "assetRecoveryAddress": "0x9876543210987654321098765432109876543210",
      "accounts": [
        {
          "accountAddress": "0x9876543210987654321098765432109876543210",
          "childContractScope": 0
        }
      ]
    }
  ],
  "contact": [
    {
      "name": "Security Team",
      "contact": "security@myprotocol.com"
    },
    {
      "name": "Discord",
      "contact": "MyProtocol#1234"
    }
  ],
  "bountyTerms": {
    "bountyPercentage": 10,
    "bountyCapUSD": 1000000,
    "retainable": true,
    "identity": 0,  // 0=Anonymous, 1=KYC
    "diligenceRequirements": "Standard security review and disclosure process",
    "aggregateBountyCapUSD": 5000000
  }
}
```

### Supported Chains (CAIP-2 Format)
The registry supports 50 major chains. Examples:
- `eip155:1` - Ethereum Mainnet
- `eip155:137` - Polygon
- `eip155:56` - BSC
- `eip155:42161` - Arbitrum One
- `eip155:10` - Optimism
- `eip155:43114` - Avalanche C-Chain
- `eip155:250` - Fantom
- And 43 more...

## 🔧 Program Instructions

### Registry Management
- `initialize_registry(owner: Pubkey)` - Initialize new registry
- `set_valid_chains(chains: Vec<String>)` - Set supported chains (owner only)

### Agreement Operations  
- `create_agreement(params: AgreementInitParams, owner: Pubkey)` - Create agreement
- `create_and_adopt_agreement(params: AgreementInitParams, owner: Pubkey)` - Create and adopt
- `adopt_safe_harbor(agreement: Pubkey)` - Adopt existing agreement
- `add_chains(chains: Vec<Chain>)` - Add chains to agreement (owner only)
- `add_accounts(caip2_chain_id: String, accounts: Vec<AccountInScope>)` - Add accounts (owner only)

### Key Changes for Owner Address Support
All owner-requiring instructions now accept `UncheckedAccount<'info>` instead of `Signer<'info>`, allowing arbitrary addresses to be specified as owners while the deployer signs the transaction.

## 📈 Progressive Creation Process

For large agreements, the system uses this process:

### 1. Initial Creation
```
Create agreement with minimal data:
- First chain only (or up to 3 chains max)
- No accounts initially
- All metadata (protocol name, bounty terms, etc.)
```

### 2. Add Remaining Chains (if needed)
```
Batch size: 5 chains per transaction
For each batch:
  - Validate chains against registry
  - Add to agreement
  - Resize account as needed
```

### 3. Add All Accounts
```
Batch size: 5 accounts per transaction
For each chain:
  For each batch of accounts:
    - Add accounts to specific chain
    - Resize account as needed
```

### 4. Verification
```
- Fetch final agreement state
- Verify all chains and accounts added
- Report success/failure status
```

## 🎯 Examples

### Simple Single-Chain Agreement
```bash
# Create test-simple.json
echo '{
  "protocolName": "Simple Protocol",
  "agreementURI": "https://simple.com/policy",
  "chains": [{
    "id": "eip155:1",
    "assetRecoveryAddress": "0x1234567890123456789012345678901234567890",
    "accounts": [{
      "accountAddress": "0x1234567890123456789012345678901234567890",
      "childContractScope": 0
    }]
  }],
  "contact": [{"name": "Team", "contact": "team@simple.com"}],
  "bountyTerms": {
    "bountyPercentage": 10,
    "bountyCapUSD": 100000,
    "retainable": true,
    "identity": 0,
    "diligenceRequirements": "Standard review",
    "aggregateBountyCapUSD": 0
  }
}' > test-simple.json

# Create with custom owner (single transaction)
npm run adopt test-simple.json dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB
```

### Complex Multi-Chain Agreement
```bash
# Use provided agreement-data-sample.json (2 chains, 9 accounts)
# Requires owner keypair for progressive creation
npm run adopt agreement-data-sample.json
```

## 🔍 Debugging & Troubleshooting

### Common Issues

#### Transaction Too Large Error
```
Error: Transaction too large: 1399 > 1232
```
**Solution**: Agreement automatically uses progressive strategy. Ensure you have owner keypair (not just address) for complex agreements.

#### Insufficient Funds for Rent
```
Error: Transaction results in an account with insufficient funds for rent
```
**Solution**: 
1. Set `PREFUND_AGREEMENT_SOL=1.0` (or higher)
2. Ensure owner wallet has sufficient SOL
3. Use progressive creation (requires owner keypair)

#### Chain Not Found Error
```
AnchorError: ChainNotFound
```
**Solution**: Check your chain IDs against supported chains in registry. Use exact CAIP-2 format (e.g., `eip155:1`).

### Debug Mode
Add detailed logging:
```bash
export ANCHOR_LOG=true
npm run adopt your-agreement.json
```

## 🧪 Testing

### Unit Tests
```bash
anchor test
```

### Integration Testing
```bash
# Test simple agreement creation
npm run adopt test-simple-agreement.json

# Test complex agreement creation  
npm run adopt agreement-data-sample.json

# Test owner address mode
npm run adopt test-simple-agreement.json dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB

# Query created agreement
npm run query <agreement-address>
```

## 🔒 Security Model

### Access Control
- **Registry Owner**: Can set valid chains, has administrative control
- **Agreement Owner**: Can modify their agreements, add chains/accounts
- **Deployer**: Signs transactions but doesn't need to be the owner

### Chain Validation
- Strict CAIP-2 format validation
- Only registry-approved chains accepted
- Prevents invalid chain adoptions

### Account Safety
- Dynamic resizing with bounds checking
- Proper rent handling for account growth
- Transaction size validation and batching

## 🚀 Deployment

### Devnet Deployment
```bash
# Deploy program
anchor deploy --provider.cluster devnet

# Initialize registry and chains
npm run deploy
```

### Mainnet Deployment
```bash
# Build optimized program
anchor build --verifiable

# Deploy to mainnet
anchor deploy --provider.cluster mainnet-beta

# Initialize registry
npm run deploy
```

## 📊 Performance & Costs

### Transaction Costs (Devnet/Mainnet estimates)
- **Simple Agreement**: ~0.01 SOL
- **Complex Agreement (Progressive)**: ~0.05-0.10 SOL  
- **Registry Deployment**: ~0.02 SOL
- **Account Rent**: ~0.001-0.01 SOL per agreement (varies by size)

### Optimization Tips
1. **Minimize String Data**: Shorter protocol names and URIs reduce transaction size
2. **Batch Related Accounts**: Group accounts by chain for efficiency
3. **Use Progressive Mode**: For >5 accounts, progressive creation is more reliable
4. **Prefund Agreements**: Set `PREFUND_AGREEMENT_SOL` for large agreements

## 🔄 Migration from EVM

### Key Differences
| Aspect | EVM | Solana |
|--------|-----|--------|
| Transaction Size | Unlimited (gas limit) | ~1232 bytes hard limit |
| Owner Specification | `msg.sender` | Configurable (deployer vs owner) |
| Account Storage | Dynamic | Fixed size + manual resizing |
| Cost Model | Gas per operation | Flat fee + rent |

### Migration Benefits
- **Lower Costs**: Significantly cheaper than Ethereum
- **Faster Finality**: ~1-2 second confirmation vs minutes
- **Better UX**: Predictable costs and faster execution
- **Same Logic**: Identical business rules and data structures

### API Equivalents (EVM → Solana)
- **Registry chains**:
  - EVM: `registry.setValidChains(chainIds)` → Solana: `program.methods.setValidChains(chainIds).rpc()`
- **Create agreement**:
  - EVM: `factory.createAgreement(params)` → Solana: `program.methods.createAgreement(params, owner).rpc()`
- **Adopt agreement**:
  - EVM: `registry.adoptSafeHarborV2(addr)` → Solana: `program.methods.adoptSafeHarbor(addr).rpc()`

### Frontend Integration Example
```typescript
import { Program } from '@coral-xyz/anchor';

const program = new Program(idl, programId, { connection, wallet });
await program.methods
  .createAndAdoptAgreement(params, ownerPublicKey)
  .rpc();
```

### Migration Checklist
- [ ] Install Solana CLI, Anchor, Node.js
- [ ] `anchor build` to generate IDL/types
- [ ] `anchor deploy` (Devnet) and `npm run deploy` to init registry
- [ ] Update agreement creation to pass explicit `owner` pubkey
- [ ] Size-aware agreement data (see Transaction Size Guide)
- [ ] Update error handling to Anchor errors
- [ ] Port tests to account-based flows

### Common Pitfalls
- Expecting unlimited tx size (EVM). Solana has ~1232 bytes; use progressive creation for complex data.
- Assuming `msg.sender` is owner. On Solana you pass `owner` explicitly and can separate deployer from owner.
- Forgetting to create/sign for new accounts. Account keypairs must be generated and provided.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Run the test suite (`anchor test`)
6. Submit a pull request

### Development Guidelines
- Follow Rust/Anchor best practices
- Add comprehensive tests for new features
- Update documentation for user-facing changes
- Consider transaction size implications for new data structures

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE.md) file for details.

---

## 🎯 Quick Start Summary

```bash
# 1. Setup
npm install && anchor build

# 2. Deploy registry  
npm run deploy

# 3. Create simple agreement with custom owner
npm run adopt test-simple-agreement.json dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB

# 4. Create complex agreement (requires owner keypair)
npm run adopt agreement-data-sample.json

# 5. Query agreement
npm run query <agreement-address>
```

*This Solana implementation achieves complete feature parity with Ethereum Safe Harbor Registry V2 while providing EVM-like owner specification and intelligent transaction size management.*