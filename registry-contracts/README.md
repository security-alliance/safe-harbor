## Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a smart contract written in Solidity which serves three main purposes:

1. Allow protocols to officially adopt the agreement.
2. Store the agreement details on-chain for Whitehat ease-of-use.
3. Allow for future updates to the agreement terms.

### Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation). To test the contracts, use `forge test`.

There are 3 contracts in this system:

-   `SafeHarborRegistry` - Where a mapping of entities to `AgreementV1` addresses are stored and where agreement factories can be enabled or disabled.
-   `AgreementV1Factory` - Where new Agreements are deployed by protocols calling the `adoptSafeHarbor()` method to officially adopt the agreement.
-   `AgreementV1` - Where details for a specific agreement are stored.

#### Setup Flow

1. The `SafeHarborRegistry` contract is deployed with the admin as `tx.origin`.
2. The `AgreementV1Factory` contract is deployed with the `SafeHarborRegistry` address passed in as a constructor argument.
3. The `SafeHarborRegistry` admin calls `enableFactory()` on `SafeHarborRegistry` with the `AgreementV1Factory` address.

In the future SEAL may create newer versions of the Safe Harbor Agreement. When this happens a new factory (e.g. `AgreementV2Factory`) will be deployed and the admin will call `enableFactory()` on `SafeHarborRegistry` with the new factory's address. Optionally, the admin may disable the old factory to prevent new adoptions using the old agreement structure.

#### Adoption Flow

1. A protocol calls `adoptSafeHarbor()` on an `AgreementFactory` with their agreement details.
2. The factory creates an `Agreement` contract containing the provided agreement details.
3. The factory adds the `Agreement` contract address to the `SafeHarborRegistry`.

A protocol may update their agreement details using any enabled factory. To do so, the protocol calls `adoptSafeHarbor()` on an agreement factory with their new agreement details. This will create a new `Agreement` contract and add the contract address to the `SafeHarborRegistry`.

Calling `adoptSafeHarbor()` is considered the legally binding action in the agreement. The `tx.origin` should represent the decision-making authority of the protocol.

#### Reading Data Flow

1. Query the `SafeHarborRegistry` contract with the protocol address to get the protocol's `AgreementV1` address.
2. Query the protocol's `Agreement` contract with `getDetails()` to get the structured agreement details.

Different versions may have different `AgreementDetails` structs. All `Agreement` and `AgreementFactory` contracts will include a `version()` method. This allows a user to know what struct to use when decoding some queried agreement details.

### Deployments

The Safe Harbor Registry will be deployed using the deterministic deployment proxy described here: https://github.com/Arachnid/deterministic-deployment-proxy, which is built into Foundry by default.

To deploy the registry to an EVM-compatible chain where it is not currently deployed:

1. Ensure the deterministic-deployment-proxy is deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C, and if it's not, deploy it using [the process mentioned above](https://github.com/Arachnid/deterministic-deployment-proxy).
2. Deploy the registry using the above proxy with salt `bytes32(0)` from the EOA that will become the registry admin. The file [`script/SafeHarborRegistryDeploy.s.sol`](script/SafeHarborRegistryDeploy.s.sol) is a convenience script for this task. To use it, set the `REGISTRY_DEPLOYER_PRIVATE_KEY` environment variable to a private key that can pay for the deployment transaction costs. Then, run the script using:
    ```
    forge script SafeHarborRegistryDeploy --rpc-url <CHAIN_RPC_URL> --verify --etherscan-api-key <ETHERSCAN_API_KEY> --broadcast -vvvv
    ```
