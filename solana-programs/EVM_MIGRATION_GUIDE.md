# EVM to Solana Migration Guide

This guide helps developers migrate from the Ethereum Safe Harbor Registry V2 to the Solana implementation.

## 🔄 Core Differences

| Aspect | EVM (Ethereum) | Solana |
|--------|---------------|---------|
| **Owner Specification** | `msg.sender` (automatic) | Configurable (deployer vs owner) |
| **Transaction Size** | Unlimited (gas limit) | ~1232 bytes hard limit |
| **Account Storage** | Dynamic (pay per byte) | Fixed size + manual resizing |
| **Cost Model** | Gas price × operations | Flat fee + rent |
| **Finality** | 12+ seconds | 1-2 seconds |
| **State Management** | Global state | Account-based |

## 🎯 API Equivalents

### EVM Contract Calls → Solana Instructions

#### Registry Operations
```solidity
// EVM
registry.setValidChains(chainIds);
registry.setInvalidChains(chainIds);
```

```typescript
// Solana  
await program.methods.setValidChains(chainIds).rpc();
await program.methods.setInvalidChains(chainIds).rpc();
```

#### Agreement Creation
```solidity
// EVM - Owner is always msg.sender
factory.createAgreement(params);
```

```typescript
// Solana - Owner is configurable
await program.methods
  .createAgreement(params, ownerPublicKey)  // Can specify any owner
  .rpc();
```

#### Agreement Adoption
```solidity
// EVM
registry.adoptSafeHarborV2(agreementAddress);
```

```typescript
// Solana
await program.methods
  .adoptSafeHarbor(agreementAddress)
  .rpc();
```

## 🔧 Data Structure Mapping

### Agreement Parameters
```solidity
// EVM
struct AgreementParams {
    string protocolName;
    string agreementUri;
    Chain[] chains;
    Contact[] contactDetails;
    BountyTerms bountyTerms;
}
```

```rust
// Solana (same structure!)
pub struct AgreementInitParams {
    pub protocol_name: String,
    pub agreement_uri: String,
    pub chains: Vec<Chain>,
    pub contact_details: Vec<Contact>,
    pub bounty_terms: BountyTerms,
}
```

### Chain Structure
```solidity
// EVM
struct Chain {
    string caip2ChainId;
    address assetRecoveryAddress;
    AccountInScope[] accounts;
}
```

```rust
// Solana (identical!)
pub struct Chain {
    pub caip2_chain_id: String,
    pub asset_recovery_address: String,  // String instead of address
    pub accounts: Vec<AccountInScope>,
}
```

## 🚀 Migration Steps

### 1. Environment Setup
```bash
# Install Solana tools
sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"

# Install Anchor
npm i -g @coral-xyz/anchor-cli

# Clone Solana implementation
git clone <repo> && cd solana-programs
npm install && anchor build
```

### 2. Deploy Registry
```bash
# Deploy registry with all valid chains
npm run deploy
```

### 3. Migrate Agreement Creation Logic

#### Before (EVM)
```typescript
// EVM - Owner is always the deployer
const tx = await agreementFactory.createAgreement({
  protocolName: "MyProtocol",
  agreementUri: "https://myprotocol.com/terms",
  chains: [/* ... */],
  contactDetails: [/* ... */],
  bountyTerms: {/* ... */}
});
```

#### After (Solana)
```typescript
// Solana - Owner can be anyone
const tx = await program.methods
  .createAndAdoptAgreement(
    {
      protocolName: "MyProtocol", 
      agreementUri: "https://myprotocol.com/terms",
      chains: [/* ... */],
      contactDetails: [/* ... */],
      bountyTerms: {/* ... */}
    },
    ownerPublicKey  // Can be different from deployer
  )
  .accounts({
    registry: registryPda,
    agreement: agreementKeypair.publicKey,
    owner: ownerPublicKey,
    adopter: deployerPublicKey,
    payer: deployerPublicKey,
    systemProgram: SystemProgram.programId,
  })
  .signers([agreementKeypair])
  .rpc();
```

### 4. Handle Transaction Size Constraints

#### EVM (No Constraints)
```typescript
// EVM - Can include unlimited data in one transaction
const tx = await factory.createAgreement({
  chains: [/* 50 chains with 1000+ accounts */]
});
```

#### Solana (Size-Aware)
```typescript
// Solana - Automatically handles size constraints
const agreement = await createAgreement({
  chains: [/* 50 chains with 1000+ accounts */]
});
// System automatically uses progressive creation if needed
```

## 🎯 Owner Model Migration

### EVM Limitation
```solidity
// EVM - Owner is always msg.sender (deployer)
function createAgreement(params) {
    agreement.owner = msg.sender;  // No choice
}
```

### Solana Flexibility  
```typescript
// Solana - Three ownership models:

// 1. Same as EVM (deployer is owner)
createAgreement(params, deployer.publicKey);

// 2. Specify custom owner (like EVM factory pattern)
createAgreement(params, customOwner.publicKey);

// 3. Multi-sig scenarios
createAgreement(params, multisigAddress);
```

## 📊 Cost Comparison

### Typical Transaction Costs

| Operation | Ethereum (Gas) | Solana (SOL) | USD Equivalent* |
|-----------|---------------|-------------|----------------|
| Deploy Registry | 2M gas (~$20) | 0.02 SOL (~$0.50) | 40x cheaper |
| Create Simple Agreement | 500K gas (~$5) | 0.01 SOL (~$0.25) | 20x cheaper |
| Create Complex Agreement | 1M gas (~$10) | 0.05 SOL (~$1.25) | 8x cheaper |
| Adopt Agreement | 100K gas (~$1) | 0.005 SOL (~$0.125) | 8x cheaper |

*Estimates based on ETH=$2000, SOL=$25

### Rent Model
```typescript
// Solana requires account rent (one-time)
const rentExemptAmount = await connection.getMinimumBalanceForRentExemption(
  agreementAccountSize
);
// Typically 0.001-0.01 SOL per agreement
```

## 🔍 Error Handling Migration

### EVM Errors
```solidity
// EVM - Gas estimation failures
require(agreement.owner == msg.sender, "Unauthorized");
```

### Solana Errors  
```typescript
// Solana - More specific error types
try {
  await program.methods.updateAgreement(params).rpc();
} catch (error) {
  if (error.error?.errorCode?.code === 'AccountNotSigner') {
    // Handle authorization error
  } else if (error.message.includes('Transaction too large')) {
    // Handle size constraints
  }
}
```

## 🧪 Testing Migration

### EVM Test Pattern
```typescript
// EVM - Simple unit tests
it("should create agreement", async () => {
  const tx = await factory.createAgreement(params);
  const agreement = await getAgreement(tx.agreementAddress);
  expect(agreement.owner).to.equal(deployer.address);
});
```

### Solana Test Pattern
```typescript
// Solana - Account-based testing
it("should create agreement", async () => {
  const agreementKeypair = Keypair.generate();
  
  await program.methods
    .createAgreement(params, owner.publicKey)
    .accounts({
      agreement: agreementKeypair.publicKey,
      owner: owner.publicKey,
      // ... other accounts
    })
    .signers([agreementKeypair])
    .rpc();
    
  const agreement = await program.account.agreement.fetch(
    agreementKeypair.publicKey
  );
  expect(agreement.owner.toString()).to.equal(owner.publicKey.toString());
});
```

## 🛠️ Development Workflow Changes

### EVM Development
```bash
# EVM workflow
npx hardhat compile
npx hardhat test
npx hardhat deploy --network sepolia
```

### Solana Development
```bash
# Solana workflow  
anchor build          # Compile program
anchor test           # Run tests
anchor deploy         # Deploy to cluster
npm run deploy        # Initialize registry
```

## 📱 Frontend Integration

### EVM Integration
```typescript
// EVM - Web3 provider
const provider = new ethers.providers.Web3Provider(window.ethereum);
const contract = new ethers.Contract(address, abi, provider);
const tx = await contract.createAgreement(params);
```

### Solana Integration
```typescript
// Solana - Wallet adapter + Anchor
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { Program } from '@coral-xyz/anchor';

const { connection } = useConnection();
const wallet = useWallet();
const program = new Program(idl, programId, { connection, wallet });

const tx = await program.methods
  .createAgreement(params, ownerPublicKey)
  .rpc();
```

## 🚨 Common Migration Pitfalls

### 1. Account Management
```typescript
// ❌ EVM thinking - no account creation needed
await program.methods.createAgreement(params).rpc();

// ✅ Solana reality - must create accounts first
const agreementKeypair = Keypair.generate();
await program.methods
  .createAgreement(params, owner)
  .accounts({
    agreement: agreementKeypair.publicKey,
    // ... must specify all accounts
  })
  .signers([agreementKeypair])
  .rpc();
```

### 2. Transaction Size Assumptions
```typescript
// ❌ EVM thinking - unlimited data
const agreement = {
  chains: Array(100).fill(/* large chain data */),
  protocolName: "Very long protocol name with extensive details..."
};

// ✅ Solana reality - size-aware
const agreement = {
  chains: [/* reasonable amount */],
  protocolName: "Concise name"
};
// Or use progressive creation for large agreements
```

### 3. Owner Model Confusion
```typescript
// ❌ EVM assumption - owner is always deployer
const owner = deployer.address;

// ✅ Solana flexibility - owner can be anyone
const owner = customOwnerPublicKey; // Can specify any address
```

## 🎯 Migration Checklist

- [ ] **Environment Setup**: Install Solana CLI, Anchor, dependencies
- [ ] **Deploy Registry**: Run deployment script for your target network
- [ ] **Update Agreement Creation**: Add owner parameter to creation calls
- [ ] **Handle Account Management**: Create keypairs for new agreements
- [ ] **Size Optimization**: Review agreement data for transaction size limits
- [ ] **Error Handling**: Update error handling for Solana-specific errors
- [ ] **Testing**: Migrate tests to account-based model
- [ ] **Frontend Integration**: Update UI to use Solana wallet adapters
- [ ] **Cost Analysis**: Update cost estimates for new fee structure
- [ ] **Documentation**: Update user docs for new deployment addresses

## 📞 Support

For migration support:
1. Check the [main README](./README.md) for detailed usage
2. Review [Transaction Size Guide](./TRANSACTION_SIZE_GUIDE.md) for complex agreements
3. Run test deployments on devnet first
4. Open issues for migration-specific problems

---

**Migration Benefits**: Lower costs, faster finality, enhanced owner model, and identical business logic with better performance characteristics.
