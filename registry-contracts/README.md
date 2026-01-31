# Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a smart contract written in Solidity which serves three main purposes:

1. Allow protocols to officially adopt the SEAL Whitehat Safe Harbor Agreement.
2. Store the agreement details on-chain as a permanent record.
3. Allow for future updates to the agreement terms by adopters.

These registry contracts were designed for EVM-compatible chains. For non-EVM chains, new registry contracts may need to be written and separately deployed.

## V3 Deployed Addresses

V3 contracts are deployed via [CreateX](https://github.com/pcaversaccio/createx) with deterministic addresses across all supported EVM chains.

| Contract | Address | Description |
| -------- | ------- | ----------- |
| **SafeHarborRegistry** | `0x326733493E143b8904716E7A64A9f4fb6A185a2c` | Main registry for protocol adoptions |
| **ChainValidator** (proxy) | `0xd01C76ccE414d9B0a294abAFD94feD2e0B88675D` | Validates CAIP-2 chain IDs |
| **ChainValidator** (impl) | `0x1eee8E721816CD5A0033FBA6Ba93486C074dD1cB` | Implementation contract |
| **AgreementFactory** | `0xcf317fE605397bC3fae6DAD06331aE5154F277fF` | Factory for creating Agreement contracts |

> **Note:** These addresses are identical on all supported chains due to CREATE3 deployment.

> **Note:** The V3 contracts have been audited by [Cyfrin](https://www.cyfrin.io/). The smart contracts are bytecode equivilant to the [hash](https://github.com/security-alliance/safe-harbor/tree/0b0abb8b627eff87e2f7b52bf8ec484cd6ce0e32) of the audit. The audit can be found [here](documents/2026-01-13-cyfrin-safe-harbor-v2.0.pdf)

## Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation).

### Build

```bash
forge build
```

### Test

```bash
# Run unit tests
forge test

# Set your MAINNET_RPC_URL and POLYGON_RPC_URL environment variables to run integration tests
FOUNDRY_PROFILE=integration forge test

# Fork tests
forge test --fork-url <RPC_URL>
```

### Coverage

```bash
forge coverage
```

## Architecture

The V3 registry consists of three main contracts:

- **SafeHarborRegistry** - The main registry contract that tracks protocol adoptions
- **ChainValidator** - Validates CAIP-2 chain IDs for agreements
- **Agreement** - Stores the agreement details for each protocol
- **AgreementFactory** - Factory for creating Agreement contracts

### Deployment

V3 uses [CreateX](https://github.com/pcaversaccio/createx) for deterministic CREATE3 deployments, ensuring the same contract addresses across all supported chains.

```bash
# Deploy to a network
forge script script/Deploy.s.sol:DeploySafeHarbor --rpc-url <RPC_URL> --broadcast --verify
```

## Adoption

1. A protocol creates their agreement details contract using the `AgreementFactory`. This can be done using any address.
2. A protocol calls `adoptSafeHarbor()` on the `SafeHarborRegistry` with their agreement contract address. This must be done from a legally representative address of that protocol.
3. The registry records the adopted `Agreement` address as an adoption by `msg.sender`.

A protocol may update their agreement details by calling `adoptSafeHarbor()` again with a new agreement contract. Protocols may also update their details directly on their existing Agreement contract using the various setter functions.

Calling `adoptSafeHarbor()` is considered the legally binding action. The `msg.sender` should represent the decision-making authority of the protocol.

## Querying Agreements

1. Query the `SafeHarborRegistry` contract with the protocol address using `getAgreement()` to get the protocol's `Agreement` address.
2. Query the protocol's `Agreement` contract with `getDetails()` to get the structured agreement details.

All contracts include a `version()` method which returns `"3.0.0"` for V3 contracts.

## Agreement Structure

```solidity
struct AgreementDetails {
    string protocolName;           // Name of the protocol
    Contact[] contactDetails;       // Contact information for pre-notification
    Chain[] chains;                 // Scope and recovery addresses by chain
    BountyTerms bountyTerms;        // Bounty terms and conditions
    string agreementURI;            // IPFS hash or URI of the agreement document
}

struct Chain {
    string assetRecoveryAddress;    // Address to send recovered assets
    Account[] accounts;             // Accounts in scope
    string caip2ChainId;            // CAIP-2 chain identifier (e.g., "eip155:1")
}

struct Account {
    string accountAddress;          // Address of the account
    ChildContractScope childContractScope;  // Scope of child contracts
}

struct BountyTerms {
    uint256 bountyPercentage;       // Percentage of recovered funds (0-100)
    uint256 bountyCapUSD;           // Maximum bounty in USD
    bool retainable;                // Whether whitehat can retain bounty
    IdentityRequirements identity;  // KYC requirements
    string diligenceRequirements;   // Diligence requirements for Named whitehats
    uint256 aggregateBountyCapUSD;  // Optional aggregate cap across all whitehats
}
```

## Chain Validation

The `ChainValidator` contract maintains a list of valid CAIP-2 chain IDs. Only chains in this list can be used in agreements. The registry owner can add or remove valid chains using:

- `setValidChains(string[] calldata _caip2ChainIds)` - Add chains to the valid list
- `setInvalidChains(string[] calldata _caip2ChainIds)` - Remove chains from the valid list

## Access Control

| Contract | Owner | Permissions |
|----------|-------|-------------|
| **ChainValidator** | SEAL multisig | Add/remove valid chains, upgrade contract (UUPS) |
| **SafeHarborRegistry** | None | Permissionless - anyone can call `adoptSafeHarbor()` |
| **AgreementFactory** | None | Permissionless - anyone can create agreements |
| **Agreement** | Protocol | Modify agreement terms (bounty, chains, contacts, etc.) |

### ChainValidator (Upgradeable)

The `ChainValidator` is deployed behind a UUPS proxy and can be upgraded by the owner. This allows adding support for new chain ID formats or fixing bugs without redeploying the entire system.

### Agreement Ownership

Each `Agreement` contract is owned by the address that created it (typically a protocol's governance or multisig). Only the owner can:
- Update bounty terms
- Add/remove chains and accounts
- Modify contact details
- Transfer ownership

## Security Considerations for Whitehats

**MEV and Front-running**: The registry does not provide protection against MEV or front-running. If a protocol modifies their agreement terms (e.g., bounty percentage, retainability) while a recovery transaction is in flight, the new terms will apply. Whitehats should:

1. **Use private mempools** (e.g., Flashbots Protect) when submitting recovery transactions
2. **Assume protocols may act adversarially** - verify terms immediately before submitting
3. **Snapshot agreement terms off-chain** as evidence before initiating any recovery

The protocol makes no guarantees about the timing or atomicity of agreement changes relative to recovery transactions.

## License

MIT
