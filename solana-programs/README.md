# Safe Harbor Registry - Solana Implementation

This repository contains the Solana/Anchor implementation of the Safe Harbor Registry V2 contracts, providing **complete feature parity** with the original Ethereum implementation found in `../registry-contracts/`.

## Key Features

This Solana implementation maintains full compatibility with the EVM V2 contracts while leveraging Solana's advantages:

- **Dynamic Storage**: Unlimited chains and accounts per agreement using dynamic account resizing
- **No Hardcoded Limits**: Removed all artificial constraints present in earlier versions
- **Complete V2 Parity**: All EVM V2 functionality including factory patterns and complex data structures
- **Optimized Architecture**: Uses PDAs, Anchor framework, and efficient account management

**Architectural Improvements:**
- Dynamic account resizing with `resize()` method for unlimited storage
- Automatic space calculation based on actual data requirements
- Efficient batch operations for chain management
- Clean separation of deployment, adoption, and query operations

## Overview

The Safe Harbor Registry is a decentralized system for managing security agreements between protocols and security researchers. It enables protocols to register their security terms and allows researchers to adopt these agreements, creating a transparent framework for responsible disclosure and bug bounty programs.

## Architecture

### Core Components

1. **Registry Account** - Central registry with dynamic storage for chains and agreement adoptions
2. **Agreement Account** - Individual agreements with unlimited chains and accounts
3. **Dynamic Resizing** - Automatic account expansion as data grows
4. **Events** - Comprehensive event emissions for all state changes

### Key Features

- **Unlimited Storage**: No caps on chains, accounts, or agreements
- **Owner-controlled Registry** with fallback registry support  
- **Chain Validation** using CAIP-2 chain IDs (e.g., `eip155:1` for Ethereum mainnet)
- **Dynamic Agreement Creation** with unlimited terms, contacts, and accounts
- **Flexible Adoption** supporting complex multi-chain scenarios
- **Access Control** with proper owner validation
- **Batch Operations** for efficient chain management

## Project Structure

```
solana-programs/
├── programs/safe_harbor/
│   └── src/lib.rs                    # Main Solana program with dynamic resizing
├── tests/
│   └── safe_harbor_tests.rs          # Comprehensive test suite
├── scripts/
│   ├── deploy-and-set-chains.ts      # Deploy registry and set all valid chains
│   ├── adopt-agreement.ts            # Create and adopt agreements
│   └── get-agreement-details.ts      # Query agreement information
└── target/                           # Build artifacts and IDL
```

## Data Structures

### Registry Account (Dynamic)
```rust
pub struct Registry {
    pub owner: Pubkey,
    pub fallback_registry: Option<Pubkey>,
    pub valid_chains: Vec<String>,           // Unlimited chains
    pub agreements: AccountMap,              // Unlimited agreements
}
```

### Agreement Account (Dynamic)
```rust
pub struct Agreement {
    pub owner: Pubkey,
    pub protocol_name: String,
    pub agreement_uri: String,
    pub chains: Vec<Chain>,                  // Unlimited chains per agreement
    pub contact_details: Vec<Contact>,       // Unlimited contacts
    pub bounty_terms: BountyTerms,
}
```

## Installation & Setup

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
Set environment variables for script configuration:
```bash
# Solana network configuration
export ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
export ANCHOR_WALLET=~/.config/solana/id.json

# Script-specific configuration
export OWNER_KEYPAIR_PATH=./owner-keypair.json
export AGREEMENT_DATA_PATH=./agreement-data.json
export SHOULD_ADOPT=true  # For adopt-agreement script
```

## Usage

### 1. Deploy Registry and Set Valid Chains
```bash
npx ts-node scripts/deploy-and-set-chains.ts
```

This will:
- Deploy a new registry (or use existing one)
- Set all valid chains from the EVM V2 implementation
- Save deployment info to `deployment-info.json`

### 2. Create and Adopt an Agreement
```bash
# Create agreement-data.json with your protocol details
npx ts-node scripts/adopt-agreement.ts
```

This will:
- Load or generate owner keypair
- Create agreement from JSON data
- Optionally adopt the agreement (controlled by SHOULD_ADOPT env var)
- Save agreement info to `agreement-info.json`

### 3. Query Agreement Details
```bash
npx ts-node scripts/get-agreement-details.ts
```

This will:
- Fetch complete agreement details
- Display formatted information
- Check adoption status in registry
- Save details to `agreement-details.json`

## Agreement Data Format

Create `agreement-data.json` with your protocol details:

```json
{
  "protocolName": "MyProtocol",
  "agreementUri": "https://myprotocol.com/security-policy",
  "chains": [
    {
      "caip2ChainId": "eip155:1",
      "accounts": [
        {
          "accountType": "Treasury",
          "accountAddress": "0x1234567890123456789012345678901234567890"
        },
        {
          "accountType": "Multisig",
          "accountAddress": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
        }
      ]
    },
    {
      "caip2ChainId": "eip155:137",
      "accounts": [
        {
          "accountType": "Treasury",
          "accountAddress": "0x9876543210987654321098765432109876543210"
        }
      ]
    }
  ],
  "contactDetails": [
    {
      "contactType": "Email",
      "contact": "security@myprotocol.com"
    },
    {
      "contactType": "Discord",
      "contact": "MyProtocol#1234"
    }
  ],
  "bountyTerms": {
    "bountyPercentage": 10,
    "bountyCapUsd": 1000000,
    "retainable": true,
    "aggregateBountyCapUsd": 5000000
  }
}
```

## Program Instructions

### Core Instructions

#### `initialize_registry(owner: Pubkey)`
Initialize a new registry with dynamic storage capabilities.

#### `set_valid_chains(chains: Vec<String>)`
Set valid CAIP-2 chain IDs with automatic account resizing (owner only).

#### `set_invalid_chains(chains: Vec<String>)`
Remove chains from valid list with account optimization (owner only).

#### `create_agreement(params: AgreementInitParams)`
Create agreement with unlimited chains and accounts using dynamic resizing.

#### `adopt_safe_harbor(agreement: Pubkey)`
Adopt existing agreement with registry validation and resizing.

#### `create_and_adopt_agreement(params: AgreementInitParams)`
Combined instruction for efficient agreement creation and adoption.

#### `update_agreement_uri(new_uri: String)`
Update agreement URI (agreement owner only).

### Dynamic Features

- **Automatic Resizing**: All instructions automatically resize accounts as needed
- **Unlimited Storage**: No caps on chains, accounts, or agreements
- **Batch Operations**: Efficient handling of large chain lists
- **Space Optimization**: Dynamic space calculation based on actual data

## Events

The program emits comprehensive events for all state changes:

- `RegistryInitialized { owner: Pubkey }` - New registry creation
- `ChainValidityChanged { chains: Vec<String>, valid: bool }` - Chain updates
- `AgreementCreated { agreement: Pubkey }` - New agreement creation
- `SafeHarborAdoption { entity: Pubkey, old_details: Pubkey, new_details: Pubkey }` - Agreement adoption
- `AgreementUpdated { agreement: Pubkey }` - Agreement modifications

## Testing

The comprehensive test suite validates:
- Dynamic registry initialization and ownership
- Unlimited chain validation management
- Agreement creation with complex multi-chain scenarios
- Agreement adoption with automatic resizing
- Error handling and access control
- Dynamic account space management

Run tests with:
```bash
anchor test
```

## EVM V2 Compatibility

### Complete Feature Parity

This Solana implementation provides **100% feature parity** with the EVM V2 contracts:

- **Registry Management**: Identical owner controls and fallback registry support
- **Chain Validation**: Same CAIP-2 chain ID format and validation logic
- **Agreement Structure**: Preserved all data fields and relationships
- **Adoption Logic**: Identical adoption rules and validation
- **Event Emissions**: Equivalent event data with Solana formatting

### Architectural Advantages

- **Dynamic Storage**: Overcomes Solana's fixed account limitation using `resize()`
- **No Storage Limits**: Unlimited chains, accounts, and agreements like EVM
- **Efficient Operations**: Batch chain management and optimized space usage
- **Cost Effective**: Lower transaction costs compared to Ethereum
- **Performance**: Faster transaction finality on Solana

### Migration Benefits

- **Same Interface**: Identical business logic and data structures
- **Enhanced Scalability**: Dynamic resizing enables unlimited growth
- **Lower Costs**: Significantly reduced operational expenses
- **Better UX**: Faster transaction confirmation times

## Security Model

- **Owner Controls**: Registry and agreement owners have exclusive modification rights
- **Chain Validation**: Strict CAIP-2 format validation prevents invalid adoptions
- **Access Control**: Proper signer validation for all restricted operations
- **Dynamic Safety**: Account resizing includes proper bounds checking
- **Event Transparency**: Comprehensive event logging for all state changes

## Development

### Building
```bash
anchor build
```

### Testing
```bash
anchor test
```

### Deployment
```bash
# Deploy to devnet
anchor deploy --provider.cluster devnet

# Deploy to mainnet
anchor deploy --provider.cluster mainnet-beta
```

## Key Improvements Over Previous Versions

1. **Removed Hardcoded Limits**: No more 32 chain or 64 agreement caps
2. **Dynamic Resizing**: Automatic account expansion as data grows
3. **Complete V2 Parity**: All EVM V2 features now supported
4. **Clean Scripts**: Focused deployment, adoption, and query tools
5. **Optimized Architecture**: Efficient space calculation and batch operations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE.md) file for details.

---

*This Solana implementation achieves complete feature parity with Ethereum Safe Harbor Registry V2 while providing unlimited scalability through dynamic account resizing.*
