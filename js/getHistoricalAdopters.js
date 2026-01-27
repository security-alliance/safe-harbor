import { ethers } from "ethers";

// Legacy SafeHarborRegistryV2 address on mainnet
const LEGACY_REGISTRY_ADDRESS = "0x1eaCD100B0546E433fbf4d773109cAD482c34686";

// SafeHarborAdoption event ABI
const REGISTRY_ABI = [
    "event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails)"
];

async function getAdopters(rpcUrl, registryAddress = LEGACY_REGISTRY_ADDRESS) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const registry = new ethers.Contract(registryAddress, REGISTRY_ABI, provider);

    console.log(`Querying SafeHarborAdoption events from ${registryAddress}...`);

    // Query all SafeHarborAdoption events from contract deployment to latest
    const filter = registry.filters.SafeHarborAdoption();
    const events = await registry.queryFilter(filter);

    console.log(`Found ${events.length} SafeHarborAdoption events\n`);

    // Extract unique adopters (entity addresses)
    const adoptersMap = new Map();

    for (const event of events) {
        const entity = event.args.entity;
        const newDetails = event.args.newDetails;
        const blockNumber = event.blockNumber;

        // Keep the latest adoption for each entity
        if (!adoptersMap.has(entity) || adoptersMap.get(entity).blockNumber < blockNumber) {
            adoptersMap.set(entity, {
                entity,
                agreementAddress: newDetails,
                blockNumber,
                transactionHash: event.transactionHash
            });
        }
    }

    const adopters = Array.from(adoptersMap.values());

    // Print results
    console.log("Adopters:");
    console.log("-".repeat(80));
    for (const adopter of adopters) {
        console.log(`Entity: ${adopter.entity}`);
        console.log(`Agreement: ${adopter.agreementAddress}`);
        console.log(`Block: ${adopter.blockNumber}`);
        console.log(`Tx: ${adopter.transactionHash}`);
        console.log("-".repeat(80));
    }

    // Return just the entity addresses for migration
    const entityAddresses = adopters.map(a => a.entity);
    console.log("\nEntity addresses for migration:");
    console.log(JSON.stringify(entityAddresses, null, 2));

    return adopters;
}

// Main execution
const rpcUrl = process.env.MAINNET_RPC_URL || process.argv[2];

if (!rpcUrl) {
    console.error("Usage: node getAdopters.js <RPC_URL>");
    console.error("Or set MAINNET_RPC_URL environment variable");
    process.exit(1);
}

getAdopters(rpcUrl)
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error:", error);
        process.exit(1);
    });
