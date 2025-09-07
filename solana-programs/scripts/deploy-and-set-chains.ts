import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, SystemProgram } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";

// All supported chains from EVM SetChains.s.sol
const SUPPORTED_CHAINS = [
  "eip155:1",        // Ethereum
  "eip155:56",       // BSC
  "eip155:42161",    // Arbitrum
  "eip155:137",      // Polygon
  "eip155:8453",     // Base
  "eip155:43114",    // Avalanche
  "eip155:10",       // Optimism
  "tron:mainnet",    // Tron (mainnet)
  "eip155:1284",     // Moonbeam
  "eip155:1285",     // Moonriver
  "eip155:252",      // Fraxtal
  "eip155:100",      // Gnosis
  "eip155:34443",    // Mode
  "eip155:1101",     // Polygon ZkEVM
  "eip155:146",      // Sonic
  "eip155:81457",    // Blast
  "eip155:288",      // Boba
  "eip155:42220",    // Celo
  "eip155:314",      // Filecoin
  "eip155:59144",    // Linea
  "eip155:169",      // Manta Pacific
  "eip155:5000",     // Mantle
  "eip155:690",      // Berachain
  "eip155:30",       // Unichain
  "eip155:534352",   // Scroll
  "eip155:1329",     // Sei Network
  "eip155:167000",   // Taiko Alethia
  "eip155:480",      // World Chain
  "eip155:324",      // zkSync Mainnet
  "eip155:7777777",  // Zora
  "eip155:204",      // opBNB Mainnet
  "eip155:1088",     // Metis Andromeda Mainnet
  "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", // Solana Mainnet
  "stellar:pubnet",  // Stellar Mainnet
  "bip122:000000000019d6689c085ae165831e93", // Bitcoin Mainnet
  "eip155:999",      // HyperEVM
  "eip155:25",       // Cronos
  "eip155:1116",     // CORE
  "eip155:747474",   // Katana
  "eip155:369",      // Pulsechain
  "eip155:30",       // Rootstock
  "eip155:2222",     // Kava
  "eip155:8217",     // Kaia
  "eip155:200901",   // Bitlayer
  "eip155:60808",    // Bob
  "eip155:98866",    // Plume
  "eip155:43111",    // Hemi
  "eip155:14",       // Flare
  "eip155:1868",     // Soneium
  "eip155:295",      // Hedera
];

async function main() {
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

  console.log("🚀 Deploying Safe Harbor Registry and Setting Chains");
  console.log("Program ID:", program.programId.toString());

  // Derive registry PDA
  const [registryPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry")],
    program.programId
  );

  console.log("Registry PDA:", registryPda.toString());

  // Check if registry already exists
  let registryExists = false;
  let registryOwner: PublicKey | null = null;
  try {
    const registryData = await program.account.registry.fetch(registryPda);
    registryExists = true;
    registryOwner = registryData.owner;
    console.log("✅ Registry already exists");
    console.log("Registry Owner:", registryOwner.toString());
    console.log("Current Wallet:", provider.wallet.publicKey.toString());
    console.log("Existing Valid Chains:", registryData.validChains.length);
    
    // Check if we're the owner
    if (!registryOwner.equals(provider.wallet.publicKey)) {
      console.log("⚠️  You are not the owner of this registry. Cannot modify chains.");
      console.log("✅ Registry is already deployed and functional with existing chains.");
      
      // Save deployment info for existing registry
      const deploymentInfo = {
        programId: program.programId.toString(),
        registryPda: registryPda.toString(),
        owner: registryOwner.toString(),
        currentWallet: provider.wallet.publicKey.toString(),
        validChainsCount: registryData.validChains.length,
        note: "Using existing registry - not owner",
        deployedAt: new Date().toISOString(),
      };
      
      fs.writeFileSync(DEPLOYMENT_INFO_PATH, JSON.stringify(deploymentInfo, null, 2));
      console.log("📄 Deployment info saved to", DEPLOYMENT_INFO_PATH);
      return;
    }
  } catch (error) {
    console.log("📝 Registry doesn't exist, will initialize");
  }

  // Initialize registry if it doesn't exist
  if (!registryExists) {
    console.log("🔧 Initializing registry...");
    
    try {
      const initTx = await program.methods
        .initializeRegistry(provider.wallet.publicKey)
        .accountsPartial({
          registry: registryPda,
          payer: provider.wallet.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .rpc();

      console.log("✅ Registry initialized!");
      console.log("Transaction signature:", initTx);
    } catch (error) {
      console.error("❌ Error initializing registry:", error);
      return;
    }
  }

  // Set valid chains in batches to avoid transaction size limits
  const BATCH_SIZE = 10; // Process chains in smaller batches
  const batches: string[][] = [];
  
  for (let i = 0; i < SUPPORTED_CHAINS.length; i += BATCH_SIZE) {
    batches.push(SUPPORTED_CHAINS.slice(i, i + BATCH_SIZE));
  }

  console.log(`🔗 Setting ${SUPPORTED_CHAINS.length} valid chains in ${batches.length} batches...`);

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    console.log(`Processing batch ${i + 1}/${batches.length} (${batch.length} chains)...`);
    
    try {
      const setChainsTx = await program.methods
        .setValidChains(batch)
        .accountsPartial({
          registry: registryPda,
          signer: provider.wallet.publicKey,
        })
        .rpc();

      console.log(`✅ Batch ${i + 1} completed. Transaction:`, setChainsTx);
    } catch (error) {
      console.error(`❌ Error setting chains batch ${i + 1}:`, error);
      return;
    }
  }

  // Verify chains were set
  try {
    const validChains = await program.methods
      .getValidChains()
      .accountsPartial({
        registry: registryPda,
      })
      .view();

    console.log(`✅ Total valid chains set: ${validChains.length}`);
  } catch (error) {
    console.log("⚠️  Could not verify chain count:", error.message);
  }

  // Save deployment info
  const deploymentInfo = {
    programId: program.programId.toString(),
    registryPda: registryPda.toString(),
    owner: provider.wallet.publicKey.toString(),
    validChainsCount: SUPPORTED_CHAINS.length,
    deployedAt: new Date().toISOString(),
  };

  fs.writeFileSync(DEPLOYMENT_INFO_PATH, JSON.stringify(deploymentInfo, null, 2));

  console.log("\n🎉 Deployment Summary:");
  console.log("=".repeat(50));
  console.log("Program ID:", program.programId.toString());
  console.log("Registry PDA:", registryPda.toString());
  console.log("Owner:", provider.wallet.publicKey.toString());
  console.log("Valid Chains:", SUPPORTED_CHAINS.length);
  console.log("📄 Deployment info saved to", DEPLOYMENT_INFO_PATH);
  
  console.log("\n🔗 Supported Chains:");
  SUPPORTED_CHAINS.forEach((chain, index) => {
    console.log(`  ${index + 1}. ${chain}`);
  });
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exit(1);
});
