import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey } from "@solana/web3.js";
import fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";

async function main() {
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

  console.log("🔍 Querying Safe Harbor Registry");

  // Load deployment info
  const deploymentInfo = JSON.parse(
    fs.readFileSync(DEPLOYMENT_INFO_PATH, "utf8")
  );
  const registryPda = new PublicKey(deploymentInfo.registryPda);

  console.log("Registry PDA:", registryPda.toString());

  try {
    // Fetch registry data
    const registryAccount = await program.account.registry.fetch(registryPda);

    console.log("\n📊 Registry Information:");
    console.log("=".repeat(50));
    console.log("Owner:", registryAccount.owner.toString());
    console.log(
      "Fallback Registry:",
      registryAccount.fallbackRegistry?.toString() || "None"
    );
    console.log("Valid Chains:", registryAccount.validChains.length);

    console.log("\n🔗 Valid Chain IDs:");
    registryAccount.validChains.forEach((chain, index) => {
      console.log(`  ${index + 1}. ${chain}`);
    });

    console.log("\n🤝 Agreements:");
    if (registryAccount.agreements.items.length === 0) {
      console.log("  No agreements found");
    } else {
      registryAccount.agreements.items.forEach((item, index) => {
        console.log(`  ${index + 1}. Adopter: ${item.key.toString()}`);
        console.log(`     Agreement: ${item.value.toString()}`);
      });
    }

    // Test chain validity
    console.log("\n✅ Testing Chain Validity:");
    const testChains = ["eip155:1", "eip155:137", "eip155:999"];

    for (const chainId of testChains) {
      try {
        const isValid = await program.methods
          .isChainValid(chainId)
          .accounts({
            registry: registryPda,
          })
          .view();

        console.log(`  ${chainId}: ${isValid ? "✅ Valid" : "❌ Invalid"}`);
      } catch (error) {
        console.log(`  ${chainId}: ❌ Error checking validity`);
      }
    }
  } catch (error) {
    console.error("❌ Error fetching registry data:", error);
  }

  // Check for adoption info
  try {
    const adoptionInfo = JSON.parse(
      fs.readFileSync("./adoption-info.json", "utf8")
    );

    console.log("\n🎯 Recent Adoption:");
    console.log("=".repeat(50));
    console.log("Adopter:", adoptionInfo.adopter);
    console.log("Agreement:", adoptionInfo.agreement);
    console.log("Protocol:", adoptionInfo.protocolName);
    console.log("Adopted At:", adoptionInfo.adoptedAt);

    // Fetch agreement details
    try {
      const agreementPubkey = new PublicKey(adoptionInfo.agreement);
      const agreementAccount = await program.account.agreement.fetch(
        agreementPubkey
      );

      console.log("\n📋 Agreement Details:");
      console.log("=".repeat(50));
      console.log("Owner:", agreementAccount.owner.toString());
      console.log("Protocol Name:", agreementAccount.protocolName);
      console.log("Agreement URI:", agreementAccount.agreementUri);
      console.log("Chains:", agreementAccount.chains.length);
      console.log("Contacts:", agreementAccount.contactDetails.length);

      console.log("\n💰 Bounty Terms:");
      console.log(
        "  Percentage:",
        agreementAccount.bountyTerms.bountyPercentage.toString(),
        "%"
      );
      console.log(
        "  Cap (USD):",
        agreementAccount.bountyTerms.bountyCapUsd.toString()
      );
      console.log("  Retainable:", agreementAccount.bountyTerms.retainable);
      console.log(
        "  Aggregate Cap (USD):",
        agreementAccount.bountyTerms.aggregateBountyCapUsd.toString()
      );
    } catch (error) {
      console.log("⚠️  Could not fetch agreement details:", error.message);
    }
  } catch (error) {
    console.log("ℹ️  No recent adoption info found");
  }
}

main().catch((error) => {
  console.error("❌ Query failed:", error);
  process.exit(1);
});
