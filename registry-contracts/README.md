## Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a smart contract written in Solidity which serves three main purposes:

1. Allow protocols to officially adopt the agreement
2. Store the agreement details on-chain for whitehat ease-of-use
3. Allow for future updates to the agreement terms

### Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation). To test the contracts, use `forge test`.

There are 3 contracts in this system:
- `SafeHarborRegistry` - Where a mapping of entities and `AgreementV1` addresses are stored. Also where the admin enable and disable `AgreementV1Factory`s.
- `AgreementV1Factory` - Protocols will call `adoptSafeHarbor()` to officially adopt the agreement.
- `AgreementV1` - Stores the agreement details struct.

#### Setup Flow
1. The `SafeHarborRegistry` contract is deployed with the admin set to the `tx.origin`.
2. The `AgreementV1Factory` contract is deployed with the `SafeHarborRegistry` address passed in as a constructor argument.
3. The admin of `SafeHarborRegistry` will call `enableFactory` on `SafeHarborRegistry` with the `AgreementV1Factory` address.

In the future, SEAL may create newer versions of the agreement. When this happens, a new factory (e.g. `AgreementV2Factory`) will be deployed and the admin will call `enableFactory` on `SafeHarborRegistry` with the new factory address. This will allow protocols to adopt the new agreement version. Optionally the admin can disable the old factory to prevent new adoptions of the older agreement version.

#### User Flow
1. A protocol will call `adoptSafeHarbor()` to the `AgreementV1Factory` with the `AgreementDetailsV1` details.
2. A `AgreementV1` contract will be created and the details will be stored in the contract.
3. The `AgreementV1` contract address will be stored in the `SafeHarborRegistry` contract.

If the protocol would like to update the agreement details, they can call `adoptSafeHarbor()` again with the new details. This will create a new `AgreementV1` contract and this contract address will be stored in the `SafeHarborRegistry` contract.

If a new version of the agreement is created, the protocol can call `adoptSafeHarbor()` on the new factory contract to adopt the new agreement version.

Note: Calling `adoptSafeHarbor()` is considered the legally binding action in the agreement. The `tx.origin` should represent the decision-making authority of the protocol.

#### Reading Data Flow
1. Query the `SafeHarborRegistry` contract with the protocol address to get the protocol's `AgreementV1` address.
2. Query the protocol's `AgreementV1` contract with `getDetails()` to get the agreement details.

Different version will probably have different `AgreementDetails` structs, so one can query `version()` in each `AgreementV1` contract. This will allow the user to know which version of the agreement they should be decoding the `AgreementDetails` struct with.

### Deployments
The Safe Harbor Registry will be deployed using the deterministic deployment proxy described here: https://github.com/Arachnid/deterministic-deployment-proxy, which is built into Foundry by default.

To deploy the registry to an EVM-compatible chain where it is not currently deployed: 
1. Ensure the deterministic-deployment-proxy is deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C, and if it's not, deploy it using [the process mentioned above](https://github.com/Arachnid/deterministic-deployment-proxy).
2. Deploy the registry using the above proxy with salt `bytes32(0)`. The file [`script/SafeHarborRegistryDeploy.s.sol`](script/SafeHarborRegistryDeploy.s.sol) is a convenience script for this. To use it, set the `REGISTRY_DEPLOYER_PRIVATE_KEY` environment variable to a private key that can pay for the deployment transaction costs. Then, run the script using:
    ```
    forge script SafeHarborRegistryDeploy --rpc-url <CHAIN_RPC_URL> --verify --etherscan-api-key <ETHERSCAN_API_KEY> --broadcast -vvvv
    ``` 