# Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a smart contract written in Solidity which serves three main purposes:

1. Allow protocols to officially adopt the agreement.
2. Store the agreement details on-chain for Whitehat ease-of-use.
3. Allow for future updates to the agreement terms.

These registry contracts were designed for EVM-compatible chains. For non-EVM chains, new registry contracts may need to be written and seperately deployed.

# Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation). To test the contracts, use `forge test`.

There are 3 contracts in this system:

-   `SafeHarborRegistry` - Where adopted agreement addresses are stored, new agreements are registered, and agreement factories are enabled / disabled.
-   `AgreementV1Factory` - Where protocols adopt new agreement contracts.
-   `AgreementV1` - Adopted agreements created by protocols.

## Setup

1. The `SafeHarborRegistry` contract is deployed with the `AgreementV1Factory`'s address and the fallback registry as constructor arguments.
2. The `AgreementV1Factory` contract is deployed with the `SafeHarborRegistry` address as a constructor argument.

In the future SEAL may create new versions of this agreement. When this happens a new factory (e.g. `AgreementV2Factory`) and registry (e.g. `SafeHarborRegistryV2`) may be deployed. New registries will fallback to prior registries, so the latest deployed registry will act as the source of truth for all adoption details.

## Adoption

1. A protocol calls `adoptSafeHarbor()` on an `AgreementFactory` with their agreement details.
2. The factory creates an `Agreement` contract containing the provided agreement details.
3. The factory adds the `Agreement` contract address to the `SafeHarborRegistry`.

A protocol may update their agreement details using any enabled factory. To do so, the protocol calls `adoptSafeHarbor()` on an agreement factory with their new agreement details. This will create a new `Agreement` contract and update the `SafeHarborRegistry`.

Calling `adoptSafeHarbor()` is considered the legally binding action in the agreement. The `msg.sender` should represent the decision-making authority of the protocol.

### Signed Accounts

For added security, protocols may choose to sign their agreement for the scoped accounts. Both EOA and ERC-1271 signatures are supported and can be validated with the agreement's factory. Given a signed account, whitehats can be certain that the owner of the account has approved the agreement details.

AccountDetails use EIP-712 hashing for both EOA and ERC-1271 signatures for a better client-side experience.

#### Signing the Agreement Details

When preparing the final agreement details, prior to deploying on-chain, the protocol may sign the agreement details for any or all of the accounts under scope and store these signatures within the agreement details. A helper script to generate these account signatures for EOA accounts has been provided. To use it set the `SIGNER_PRIVATE_KEY` environment variable. Then, run the script using:

```
forge script GenerateAccountSignatureV1.s.sol --fork-url <YOUR_RPC_URL> -vvvv
```

#### Verification of Signed Accounts

Whitehats may use the agreement factory's `validateAccount()` method to verify that a given Account has consented to the agreement details.

## Querying Agreements

1. Query the `SafeHarborRegistry` contract with the protocol address to get the protocol's `AgreementV1` address.
2. Query the protocol's `Agreement` contract with `getDetails()` to get the structured agreement details.

Different versions may have different `AgreementDetails` structs. All `Agreement` and `AgreementFactory` contracts will include a `version()` method that can be used to infer the `AgreementDetails` structure.

# Deployment

The Safe Harbor Registry will be deployed using the deterministic deployment proxy described here: https://github.com/Arachnid/deterministic-deployment-proxy, which is built into Foundry by default.

To deploy the registry to an EVM-compatible chain where it is not currently deployed:

1. Ensure the deterministic-deployment-proxy is deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C, and if it's not, deploy it using [the process mentioned above](https://github.com/Arachnid/deterministic-deployment-proxy).
2. Deploy the registry using the above proxy with salt `bytes32(0)` from the EOA that will become the registry admin. The file [`script/SafeHarborRegistryDeploy.s.sol`](script/SafeHarborRegistryDeploy.s.sol) is a convenience script for this task. To use it, set the `REGISTRY_DEPLOYER_PRIVATE_KEY` environment variable to a private key that can pay for the deployment transaction costs. Then, run the script using:

```
forge script SafeHarborRegistryDeploy --rpc-url <CHAIN_RPC_URL> --verify --etherscan-api-key <ETHERSCAN_API_KEY> --broadcast -vvvv
```
