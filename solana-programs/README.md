# Safe Harbor Registry - Solana Implementation

This repository contains the Solana/Anchor implementation of the Safe Harbor Registry V2 contracts, converted from the original Ethereum implementation.

## Overview

The Safe Harbor Registry is a decentralized system for managing security agreements between protocols and security researchers. It allows protocols to register their security terms and researchers to adopt these agreements, creating a transparent framework for responsible disclosure and bug bounty programs.

## Architecture

### Core Components

1. **Registry Account** - Central registry that tracks valid chains and agreement adoptions
2. **Agreement Account** - Individual agreement contracts with detailed terms
3. **Events** - Emitted for key state changes (initialization, adoptions, chain updates)

### Key Features

- **Owner-controlled Registry** with fallback registry support
- **Chain Validation** using CAIP-2 chain IDs (e.g., `eip155:1` for Ethereum mainnet)
- **Agreement Creation** with detailed terms, contacts, and bounty information
- **Agreement Adoption** by users associating their wallet with agreement accounts
- **Access Control** to restrict certain actions to owners
- **Validation** to prevent duplicate chain IDs and invalid configurations

## Project Structure

```
solana-programs/
├── programs/safe_harbor/
│   └── src/lib.rs              # Main Solana program
├── tests/
│   └── safe_harbor_tests.rs    # Comprehensive test suite
├── scripts/
│   ├── deploy.ts               # Deployment script
│   ├── adopt-safe-harbor.ts    # Agreement adoption script
│   ├── query-registry.ts       # Registry query utilities
│   └── manage-chains.ts        # Chain management utilities
└── target/                     # Build artifacts and IDL
```

## Data Structures

### Registry Account
```rust
pub struct Registry {
    pub owner: Pubkey,
    pub fallback_registry: Option<Pubkey>,
    pub valid_chains: Vec<String>,
    pub agreements: KeyValueStore<Pubkey, Pubkey>,
}
```

### Agreement Account
```rust
pub struct Agreement {
    pub owner: Pubkey,
    pub protocol_name: String,
    pub agreement_uri: String,
    pub chains: Vec<Chain>,
    pub contact_details: Vec<Contact>,
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
Create a `.env` file or set environment variables:
```bash
# Solana network (devnet, testnet, mainnet-beta)
ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
ANCHOR_WALLET=~/.config/solana/id.json

# Script configuration
OWNER_KEYPAIR_PATH=./owner-keypair.json
AGREEMENT_DATA_PATH=./agreement-data.json
```

## Usage

### 1. Deploy the Registry
```bash
npm run deploy
```

This will:
- Initialize a new registry
- Set initial valid chains (Ethereum mainnet, Polygon)
- Save deployment info to `deployment-info.json`

### 2. Create and Adopt an Agreement
```bash
# Create agreement-data.json with your protocol details
npm run adopt
```

### 3. Query Registry Status
```bash
npm run query
```

### 4. Manage Valid Chains
```bash
# Add new chains
npm run manage-chains add eip155:42161 eip155:10

# Remove chains
npm run manage-chains remove eip155:999

# List current chains
npm run manage-chains list
```

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
        }
      ]
    }
  ],
  "contactDetails": [
    {
      "contactType": "Email",
      "contact": "security@myprotocol.com"
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

## API Reference

### Instructions

#### `initialize_registry(fallback_registry: Option<Pubkey>)`
Initialize a new registry with optional fallback registry.

#### `set_valid_chains(chains: Vec<String>)`
Set the list of valid CAIP-2 chain IDs (owner only).

#### `set_invalid_chains(chains: Vec<String>)`
Remove chains from the valid list (owner only).

#### `create_agreement(protocol_name: String, agreement_uri: String, ...)`
Create a new agreement with detailed terms.

#### `adopt_safe_harbor(agreement: Pubkey)`
Adopt an existing agreement, associating your wallet with it.

#### `update_agreement_uri(new_uri: String)`
Update the agreement URI (agreement owner only).

### View Functions

#### `is_chain_valid(chain_id: String) -> bool`
Check if a chain ID is valid in the registry.

#### `get_adopted_agreement(adopter: Pubkey) -> Option<Pubkey>`
Get the agreement adopted by a specific address.

## Events

The program emits events for key state changes:

- `RegistryInitialized` - When a new registry is created
- `ChainValidityChanged` - When valid chains are updated
- `AgreementCreated` - When a new agreement is created
- `SafeHarborAdopted` - When an agreement is adopted
- `AgreementUpdated` - When agreement details are modified

## Testing

The test suite covers:
- Registry initialization and ownership
- Chain validation management
- Agreement creation with various configurations
- Agreement adoption and validation
- Error cases and access control

Run tests with:
```bash
anchor test
```

## Conversion Notes

### Key Differences from Ethereum Version

1. **Account Model**: Solana uses an account-based model instead of contract storage
2. **PDAs**: Program Derived Addresses replace contract addresses
3. **Rent**: Accounts must maintain minimum balance for rent exemption
4. **Events**: Anchor events replace Ethereum logs
5. **Access Control**: Implemented through account validation instead of modifiers

### Migration Considerations

- **Chain IDs**: Same CAIP-2 format maintained for compatibility
- **Data Structures**: Preserved original structure where possible
- **Validation Logic**: Ported validation rules from Ethereum contracts
- **Events**: Similar event data with Solana-specific formatting

## Security Considerations

- **Owner Controls**: Registry owner can modify valid chains
- **Agreement Ownership**: Only agreement owners can update terms
- **Chain Validation**: Prevents adoption on invalid chains
- **Duplicate Prevention**: Validates against duplicate chain IDs
- **Access Control**: Proper signer validation for restricted operations

## Development

### Building
```bash
anchor build
```

### Testing
```bash
anchor test
```

### Linting
```bash
npm run lint
```

### Deployment
```bash
# Deploy to devnet
anchor deploy --provider.cluster devnet

# Deploy to mainnet
anchor deploy --provider.cluster mainnet-beta
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE.md) file for details.

## Support

For questions or issues:
- Create an issue in this repository
- Contact the development team
- Review the test files for usage examples

---

*This Solana implementation maintains compatibility with the original Ethereum Safe Harbor Registry V2 while leveraging Solana's unique features for improved performance and lower costs.*
