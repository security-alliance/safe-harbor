# Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a smart contract written in Solidity which serves three main purposes:

1. Allow protocols to officially adopt the SEAL Whitehat Safe Harbor Agreement.
2. Store the agreement details on-chain as a permanent record.
3. Allow for future updates to the agreement terms by adopters.

These registry contracts were designed for EVM-compatible chains. For non-EVM chains, new registry contracts may need to be written and separately deployed.

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

## License

MIT