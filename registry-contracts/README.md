# Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a smart contract written in Solidity which serves three main purposes:

1. Allow protocols to officially adopt the SEAL Whitehat Safe Harbor Agreement.
2. Store the agreement details on-chain as a permanent record.
3. Allow for future updates to the agreement terms by adopters.

These registry contracts were designed for EVM-compatible chains. For non-EVM chains, new registry contracts may need to be written and seperately deployed.

# Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation). To test the contracts, use `forge test`.

There are 2 active versions in this system:

-   `src/v2/SafeHarborRegistryV2.sol` and `src/v2/AgreementV2.sol` (current)
-   `src/v1/SafeHarborRegistry.sol` and `src/v1/AgreementV1.sol` (legacy)

## Setup

1. The `SafeHarborRegistry` contract is deployed with the fallback registry as constructor arguments.

In the future SEAL may create new versions of this agreement. When this happens a new registry (e.g. `SafeHarborRegistryV2`) may be deployed. New registries will fallback to prior registries, so the latest deployed registry will act as the source of truth for all adoption details. Old registries will always remain functional.

## Adoption

1. A protocol creates their agreement details contract using one of the provided `AgreementFactories`. This can be done using any address.
2. A protocol calls `adoptSafeHarbor()` on a `SafeHarborRegistry` with their agreement contract. This must be done from a legally representative address of that protocol.
3. The registry records the adopted `Agreement` address as an adoption by `msg.sender`.

A protocol may update their agreement details using any enabled registry. To do so, the protocol calls `adoptSafeHarbor()` on an agreement registry with their new agreement details. This will create a new `Agreement` contract and store it as the details for `msg.sender`. Protocols may also update their details on any mutable Agreement.

Calling `adoptSafeHarbor()` is considered the legally binding action. The `msg.sender` should represent the decision-making authority of the protocol.

### Using the script to adopt Safe Harbor

#### V2 Adoption (Recommended)

The V2 adoption script supports configurable options and is the recommended approach for new adoptions.

**Environment Variables:**

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DEPLOYER_PRIVATE_KEY` | ✅ | - | Private key for transaction signing |
| `AGREEMENT_OWNER` | ❌ | Deployer address | Address that will own the agreement |
| `ADOPT_TO_REGISTRY` | ❌ | `false` | Whether to adopt the agreement to the registry |

**Usage:**
```bash
cd registry-contracts
forge script script/v2/AdoptSafeHarborV2.s.sol:AdoptSafeHarborV2 --rpc-url <URL> --verify --broadcast
```

**Configuration:** The script reads agreement details from `agreementDetailsV2.json`. Make sure this file exists and contains valid agreement configuration before running the script.

#### V1 Adoption (Legacy)

For V1 adoptions:
1. Edit agreementDetails.json with the agreement details of your protocol.
2. Create a .env file and set the `DEPLOYER_PRIVATE_KEY` environment variable.
3. Run the script using:

```bash
forge script script/v1/AdoptSafeHarborV1.s.sol:AdoptSafeHarborV1 --rpc-url <URL> --verify --broadcast
```

If you would like to deploy from the protocol multisig, please contact us directly.

### V2 Utilities

#### Add chains to an existing AgreementV2

The add-chains script reads from `addChainsV2.json` and calls `AgreementV2.addChains`.

**Requirements:**

- `DEPLOYER_PRIVATE_KEY` in env (must be the current `owner()` of the agreement)
- `addChainsV2.json` in the repo root with fields:
  - `agreementAddress` (checksummed address)
  - `chains[]` objects with `id` (CAIP-2), `assetRecoveryAddress`, `accounts[]` where each account has `accountAddress` and `childContractScope` (enum as uint)

**Usage:**

```bash
cd registry-contracts
forge script script/v2/AddChainsV2.s.sol:AddChainsV2 --rpc-url <URL> --broadcast
```

#### Change AgreementV2 owner

Transfer ownership of an `AgreementV2` to a new address.

**CLI (recommended):**

```bash
cd registry-contracts
forge script script/v2/ChangeOwnerV2.s.sol:ChangeOwnerV2 \
  --sig 'run(address,address)' 0xAgreementAddress 0xNewOwnerAddress \
  --rpc-url <URL> --broadcast
```

**Env-based:**

```bash
export DEPLOYER_PRIVATE_KEY=0x...
export AGREEMENT_ADDRESS=0xAgreementAddress
export NEW_OWNER=0xNewOwnerAddress
cd registry-contracts
forge script script/v2/ChangeOwnerV2.s.sol:ChangeOwnerV2 --rpc-url <URL> --broadcast
```

#### Get AgreementV2 details

Logs the current `AgreementDetailsV2` to the console.

**CLI:**

```bash
cd registry-contracts
forge script script/v2/GetAgreementDetailsV2.s.sol:GetAgreementDetailsV2 \
  --sig 'run(address)' 0xAgreementAddress \
  --rpc-url <URL>
```

**Env-based:**

```bash
export AGREEMENT_ADDRESS=0xAgreementAddress
cd registry-contracts
forge script script/v2/GetAgreementDetailsV2.s.sol:GetAgreementDetailsV2 --rpc-url <URL>
```

### Signed Accounts

For added security, protocols may choose to sign their agreement for the scoped accounts. Both EOA and ERC-1271 signatures are supported and can be validated with the registry. Given a signed account, whitehats can be certain that the owner of the account has approved the agreement details.

`AccountDetails` use EIP-712 hashing for a better client-side experience.

#### Verification of Signed Accounts

Whitehats may use the registy's `validateAccount()` method to verify that a given Account has consented to the agreement details.

## Querying Agreements

1. Query the `SafeHarborRegistry` contract with the protocol address to get the protocol's `AgreementV*` address.
2. Query the protocol's `Agreement` contract with `getDetails()` to get the address of the structured agreement details.

Different versions may have different `AgreementDetails` structs. All `Agreement` and `SafeHarborRegistry` contracts will include a `version()` method which can be used to infer the `AgreementDetails` structure.

If no agreement is present for a given query address in a registry, the registry will check the fallback registry provided in its constructor. This allows SEAL to deploy new registries while remaining backwards-compatible.

# Deployment

The Safe Harbor Registry will be deployed using the deterministic deployment proxy described here: https://github.com/Arachnid/deterministic-deployment-proxy, which is built into Foundry by default.

To deploy the registry to an EVM-compatible chain where it is not currently deployed:

1. Ensure the deterministic-deployment-proxy is deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C, and if it's not, deploy it using [the process mentioned above](https://github.com/Arachnid/deterministic-deployment-proxy).
2. Deploy the registry using the above proxy with salt `bytes32(0)` from the EOA that will become the registry admin. The file [`script/v2/DeployRegistryV2.s.sol`](script/v2/DeployRegistryV2.s.sol) is a convenience script for this task. To use it, set the `REGISTRY_DEPLOYER_PRIVATE_KEY` environment variable to a private key that can pay for the deployment transaction costs, or use `--ledger` to deploy with a ledger account. Then, run the script using:

```
cd registry-contracts
forge script script/v2/DeployRegistryV2.s.sol:DeployRegistryV2 --rpc-url <CHAIN_RPC_URL> --verify --broadcast --ledger
```

*https://chainlist.org*
