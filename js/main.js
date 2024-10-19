import Web3 from "web3";
import sigUtil from 'eth-sig-util';
import fs from 'fs';

// Your contract's ABI and address
const artifactPath = '../registry-contracts/out/SafeHarborRegistry.sol/SafeHarborRegistry.json';
const contractAddress = "0x8f72fcf695523A6FC7DD97EafDd7A083c386b7b6";

const web3 = new Web3("http://localhost:8545");
const accounts = await web3.eth.getAccounts();
const signer = accounts[0];
const signerPrivateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

// Example AgreementDetailsV1 data to be signed
const domain = {
    name: "Safe Harbor",
    version: "1.0.0",
    chainId: 31337,
    verifyingContract: contractAddress
};

const types = {
    EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" },
    ],
    AgreementDetailsV1: [
        { name: "protocolName", type: "string" },
        { name: "contactDetails", type: "Contact[]" },
        { name: "chains", type: "Chain[]" },
        { name: "bountyTerms", type: "BountyTerms" },
        { name: "agreementURI", type: "string" }
    ],
    Contact: [
        { name: "name", type: "string" },
        { name: "contact", type: "string" }
    ],
    Chain: [
        { name: "assetRecoveryAddress", type: "address" },
        { name: "accounts", type: "Account[]" },
        { name: "id", type: "uint256" }
    ],
    Account: [
        { name: "accountAddress", type: "address" },
        { name: "childContractScope", type: "uint8" },
        { name: "signature", type: "bytes" }
    ],
    BountyTerms: [
        { name: "bountyPercentage", type: "uint256" },
        { name: "bountyCapUSD", type: "uint256" },
        { name: "retainable", type: "bool" },
        { name: "identity", type: "uint8" },
        { name: "diligenceRequirements", type: "string" }
    ]
};

// Replace this with actual data
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

async function loadABI(path) {
    try {
        const artifact = JSON.parse(fs.readFileSync(path, 'utf8'));
        const contractABI = artifact.abi;
        return contractABI;
    } catch (error) {
        console.error('Error reading ABI:', error);
        return null;
    }
}

const primaryType = "AgreementDetailsV1";

async function main() {
    // Create contract instance
    const abi = await loadABI(artifactPath);
    const contract = new web3.eth.Contract(abi, contractAddress);

    // Sign the typed data
    console.log("Signer:", signer);

    const typedData = {
        types,
        domain,
        primaryType,
        message: value
    };
    
    const signature = sigUtil.signTypedData_v4(Buffer.from(signerPrivateKey.slice(2), 'hex'), { data: typedData });
    
    // Recover the address from the typed data and signature
    const recoveredAddress = sigUtil.recoverTypedSignature_v4({
        data: typedData,
        sig: signature,
    });
    
    if (recoveredAddress.toLowerCase() !== signer.toLowerCase()) {
        console.error("Invalid signature");
        console.error("Expected:", signer);
        console.error("Recovered:", recoveredAddress);
    }

    const account = {
        accountAddress: signer,
        childContractScope: 0,
        signature
    };

    const isValid = await contract.methods.validateAccount(value, account).call();
    console.log("isValid:", isValid);
}

const identityEnumMap = {
    0: "Anonymous",
    1: "Pseudonymous",
    2: "Named",
}

const childScopeEnumMap = {
    0: "None",
    1: "ExistingOnly",
    2: "All",
}

// apply the enum maps to the value object
function prettifyValue(value) {
    
} 

main().catch(console.error);
