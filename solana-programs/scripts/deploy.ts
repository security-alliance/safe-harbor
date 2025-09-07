import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const NETWORK = process.env.ANCHOR_PROVIDER_URL || "http://127.0.0.1:8899";
const OWNER_KEYPAIR_PATH = process.env.OWNER_KEYPAIR_PATH || "./owner-keypair.json";

async function main() {
  // Configure the client to use the local cluster
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;
  
  console.log("🚀 Deploying Safe Harbor Registry V2 to Solana");
  console.log("Program ID:", program.programId.toString());
  console.log("Network:", NETWORK);

  // Load or generate owner keypair
  let ownerKeypair: Keypair;
  try {
    const ownerKeypairData = JSON.parse(fs.readFileSync(OWNER_KEYPAIR_PATH, "utf8"));
    ownerKeypair = Keypair.fromSecretKey(new Uint8Array(ownerKeypairData));
    console.log("Loaded owner keypair from:", OWNER_KEYPAIR_PATH);
  } catch (error) {
    console.log("Generating new owner keypair...");
    ownerKeypair = Keypair.generate();
    fs.writeFileSync(OWNER_KEYPAIR_PATH, JSON.stringify(Array.from(ownerKeypair.secretKey)));
    console.log("Saved owner keypair to:", OWNER_KEYPAIR_PATH);
  }

  console.log("Owner address:", ownerKeypair.publicKey.toString());

  // Derive registry PDA
  const [registryPda, registryBump] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry")],
    program.programId
  );

  console.log("Registry PDA:", registryPda.toString());

  try {
    // Check if registry is already initialized
    const registryAccount = await program.account.registry.fetch(registryPda);
    console.log("✅ Registry already initialized");
    console.log("Registry owner:", registryAccount.owner.toString());
    console.log("Valid chains:", registryAccount.validChains);
    console.log("Fallback registry:", registryAccount.fallbackRegistry?.toString() || "None");
  } catch (error) {
    // Registry not initialized, let's initialize it
    console.log("📝 Initializing registry...");
    
    const tx = await program.methods
      .initializeRegistry(ownerKeypair.publicKey)
      .rpc();

    console.log("✅ Registry initialized!");
    console.log("Transaction signature:", tx);
  }

  // Set initial valid chains
  const initialChains = [
    "eip155:1",      // Ethereum Mainnet
    "eip155:137",    // Polygon
    "eip155:42161",  // Arbitrum One
    "eip155:10",     // Optimism
    "eip155:8453",   // Base
    "eip155:43114",  // Avalanche C-Chain
    "eip155:56",     // BSC
    "eip155:100",    // Gnosis Chain
  ];

  console.log("📝 Setting valid chains...");
  
  try {
    const tx = await program.methods
      .setValidChains(initialChains)
      .signers([ownerKeypair])
      .rpc();

    console.log("✅ Valid chains set!");
    console.log("Transaction signature:", tx);
    console.log("Valid chains:", initialChains);
  } catch (error) {
    console.log("⚠️  Error setting valid chains:", error);
  }

  // Display deployment summary
  console.log("\n🎉 Deployment Summary:");
  console.log("=".repeat(50));
  console.log("Program ID:", program.programId.toString());
  console.log("Registry PDA:", registryPda.toString());
  console.log("Owner:", ownerKeypair.publicKey.toString());
  console.log("Network:", NETWORK);
  console.log("Valid Chains:", initialChains.length);
  
  // Save deployment info
  const deploymentInfo = {
    programId: program.programId.toString(),
    registryPda: registryPda.toString(),
    owner: ownerKeypair.publicKey.toString(),
    network: NETWORK,
    validChains: initialChains,
    deployedAt: new Date().toISOString(),
  };

  fs.writeFileSync("./deployment-info.json", JSON.stringify(deploymentInfo, null, 2));
  console.log("📄 Deployment info saved to deployment-info.json");
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exit(1);
});
