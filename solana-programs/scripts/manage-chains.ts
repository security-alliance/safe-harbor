import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair } from "@solana/web3.js";
import fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";
const OWNER_KEYPAIR_PATH = process.env.OWNER_KEYPAIR_PATH || "./owner-keypair.json";

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  const chains = args.slice(1);

  if (!command || (command !== "add" && command !== "remove" && command !== "list")) {
    console.log("Usage:");
    console.log("  npm run manage-chains add <chain1> <chain2> ...");
    console.log("  npm run manage-chains remove <chain1> <chain2> ...");
    console.log("  npm run manage-chains list");
    console.log("");
    console.log("Examples:");
    console.log("  npm run manage-chains add eip155:42161 eip155:10");
    console.log("  npm run manage-chains remove eip155:999");
    console.log("  npm run manage-chains list");
    process.exit(1);
  }

  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;
  
  console.log("⛓️  Managing Safe Harbor Chain Validation");

  // Load deployment info
  const deploymentInfo = JSON.parse(fs.readFileSync(DEPLOYMENT_INFO_PATH, "utf8"));
  const registryPda = new PublicKey(deploymentInfo.registryPda);

  // Load owner keypair
  const ownerKeypairData = JSON.parse(fs.readFileSync(OWNER_KEYPAIR_PATH, "utf8"));
  const ownerKeypair = Keypair.fromSecretKey(new Uint8Array(ownerKeypairData));

  console.log("Registry PDA:", registryPda.toString());
  console.log("Owner:", ownerKeypair.publicKey.toString());

  if (command === "list") {
    try {
      const registryAccount = await program.account.registry.fetch(registryPda);
      
      console.log("\n🔗 Currently Valid Chains:");
      console.log("=".repeat(50));
      
      if (registryAccount.validChains.length === 0) {
        console.log("No valid chains configured");
      } else {
        registryAccount.validChains.forEach((chain, index) => {
          console.log(`  ${index + 1}. ${chain}`);
        });
      }
    } catch (error) {
      console.error("❌ Error fetching registry data:", error);
    }
    return;
  }

  if (chains.length === 0) {
    console.error("❌ No chains specified");
    process.exit(1);
  }

  console.log(`\n📝 ${command === "add" ? "Adding" : "Removing"} chains:`, chains);

  try {
    let tx: string;
    
    if (command === "add") {
      tx = await program.methods
        .setValidChains(chains)
        .accounts({
          registry: registryPda,
          signer: ownerKeypair.publicKey,
        })
        .signers([ownerKeypair])
        .rpc();
    } else {
      tx = await program.methods
        .setInvalidChains(chains)
        .accounts({
          registry: registryPda,
          signer: ownerKeypair.publicKey,
        })
        .signers([ownerKeypair])
        .rpc();
    }

    console.log("✅ Chains updated successfully!");
    console.log("Transaction signature:", tx);

    // Show updated chain list
    const registryAccount = await program.account.registry.fetch(registryPda);
    console.log("\n🔗 Updated Valid Chains:");
    console.log("=".repeat(50));
    
    if (registryAccount.validChains.length === 0) {
      console.log("No valid chains configured");
    } else {
      registryAccount.validChains.forEach((chain, index) => {
        console.log(`  ${index + 1}. ${chain}`);
      });
    }

  } catch (error) {
    console.error("❌ Error updating chains:", error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("❌ Chain management failed:", error);
  process.exit(1);
});
