import {expect} from 'chai';

import Web3 from "web3";
import sigUtil from 'eth-sig-util';

import { loadABI, loadAddress } from '../fs.js';
import {domain} from '../domain.js';
import {types, primaryType} from '../types.js';

const artifactPath = '../registry-contracts/out/SafeHarborRegistry.sol/SafeHarborRegistry.json';
const addressPath = '../registry-contracts/broadcast/SafeHarborRegistryDeploy.s.sol/31337/run-latest.json';

// From forge created accounts, insecure
const web3 = new Web3("http://localhost:8545");
const accounts = await web3.eth.getAccounts();
const signer = accounts[0];
const signerPrivateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

describe("EIP712 Test", () => {
    it("Should successfully sign and validate signature", async () => {
        // Get registry
        const registryABI = await loadABI(artifactPath);
        const registryAddr = await loadAddress(addressPath);
        const registry = new web3.eth.Contract(registryABI, registryAddr);

        domain.verifyingContract = registryAddr;

        // Sign typedData
        const typedData = {
            types,
            domain,
            primaryType,
            message: value
        };

        const signature = sigUtil.signTypedData_v4(Buffer.from(signerPrivateKey.slice(2), 'hex'), { data: typedData });

        // Validate signature on smart contract
        const account = {
            accountAddress: signer,
            childContractScope: 0,
            signature
        };
    
        const isValid = await registry.methods.validateAccount(value, account).call();
        expect(isValid).to.be.true;
    })
})

// Mock value to be signed
const value = {
    protocolName: "ExampleProtocol",
    contactDetails: [
        {
            name: "ExampleContact",
            contact: "contact@example.com"
        }
    ],
    chains: [
        {
            assetRecoveryAddress: "0xa83114a443da1cecefc50368531cace9f37fcccb",
            accounts: [
                {
                    accountAddress: signer,
                    childContractScope: 0,
                    signature: "0x"
                }
            ],
            id: 1
        }
    ],
    bountyTerms: {
        bountyPercentage: 10,
        bountyCapUSD: 1000,
        retainable: true,
        identity: 0,
        diligenceRequirements: "Some requirements"
    },
    agreementURI: "https://example.com/agreement"
};