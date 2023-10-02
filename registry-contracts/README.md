## Safe Harbor Registry

This directory houses the "Safe Harbor Registry". This is a simple smart contract written in Solidity which serves two main purposes:

1. To provide a target for a protocol's governance to indicate their official acceptance of the agreement
2. To store the agreement parameters on-chain for whitehat ease-of-use

### Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation). To test the contracts, use `forge test`.

The main contract is the `SafeHarborRegistry`. This contract has a single function:

```solidity
function adoptSafeHarbor(AgreementDetails calldata details) external {
    // ...
}
```

As part of the official adoption of the SEAL Safe Harbor initiative, the `adoptSafeHarbor()` function should be called with the `details` that the protocol has chosen. This is considered the legally binding action in the agreement, so the `msg.sender` should represent the decision-making authority of the protocol. The agreement terms will also be saved in on-chain storage, so that anyone can inspect a Safe Harbor's adoption through the `agreements` mapping. Note that the `adoptSafeHarbor()` function can be called multiple times, so that terms can be updated if needed. 

### Deployments

Since the Safe Harbor initiative will go through an initial RFC stage before becoming finalized, the registry has not yet been deployed. However, it is intended that the registry eventually exists (or can exist) on any EVM blockchain at the same address. This will be achieved using the deterministic deployment proxy described here: https://github.com/Arachnid/deterministic-deployment-proxy, which is built into Foundry by default.

To deploy the registry to an EVM-compatible chain where it is not currently deployed: 

1. Ensure the deterministic-deployment-proxy is deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C, and if it's not, deploy it using [the process mentioned above](https://github.com/Arachnid/deterministic-deployment-proxy).

2. Deploy the registry using the above proxy with salt `bytes32(0)`. The file [`script/SafeHarborRegistryDeploy.s.sol`](script/SafeHarborRegistryDeploy.s.sol) is a convenience script for this. To use it, set the `REGISTRY_DEPLOYER_PRIVATE_KEY` environment variable to a private key that can pay for the deployment transaction costs. Then, run the script using:
    ```
    forge script script/SafeHarborRegistryDeploy.s.sol:SafeHarborRegistryDeploy --rpc-url <CHAIN_RPC_URL> --broadcast -vvvv
    ``` 