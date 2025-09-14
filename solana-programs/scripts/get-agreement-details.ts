import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";

async function main() {
  // Check for help flag
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    console.log(`
🔍 Safe Harbor Agreement Details Viewer

Usage:
  npx ts-node scripts/get-agreement-details.ts <agreement-address>
  npx ts-node scripts/get-agreement-details.ts --help

Arguments:
  agreement-address    The public key of the agreement to query

Environment Variables:
  AGREEMENT_ADDRESS    Alternative way to specify the agreement address

Examples:
  npx ts-node scripts/get-agreement-details.ts ALuW9Hk1SJTzUyMQMhFbLiJDBp4dwJgBiah1qNP8xQRp
  AGREEMENT_ADDRESS=ALuW9Hk1SJTzUyMQMhFbLiJDBp4dwJgBiah1qNP8xQRp npx ts-node scripts/get-agreement-details.ts
    `);
    return;
  }

  console.log("🔍 Getting Agreement Details");

  // Get agreement address from command line or environment variable
  const agreementAddress = process.argv[2] || process.env.AGREEMENT_ADDRESS;

  if (!agreementAddress) {
    console.error("❌ Please provide agreement address");
    console.log("Usage:");
    console.log("  npx ts-node scripts/get-agreement-details.ts <agreement-address>");
    console.log("  OR");
    console.log("  AGREEMENT_ADDRESS=<pubkey> npx ts-node scripts/get-agreement-details.ts");
    console.log("  OR");
    console.log("  npx ts-node scripts/get-agreement-details.ts --help");
    process.exit(1);
  }

  let agreementPubkey: PublicKey;
  try {
    agreementPubkey = new PublicKey(agreementAddress);
  } catch (error) {
    console.error("❌ Invalid agreement address:", agreementAddress);
    process.exit(1);
  }

  console.log("Agreement address:", agreementPubkey.toString());

  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

  // Derive registry PDA
  const [registryPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry")],
    program.programId
  );
  console.log("Registry PDA:", registryPda.toString());

  // Fetch agreement details
  try {
    const agreement = await program.account.agreement.fetch(agreementPubkey);

    console.log("\n📄 Agreement Details:");
    console.log("=".repeat(60));
    console.log("Address:", agreementPubkey.toString());
    console.log("Owner:", agreement.owner.toString());
    console.log("Protocol Name:", agreement.protocolName);
    console.log("Agreement URI:", agreement.agreementUri);

    console.log("\n👥 Contact Details:");
    if (agreement.contactDetails.length === 0) {
      console.log("  No contacts specified");
    } else {
      agreement.contactDetails.forEach((contact, index) => {
        console.log(`  ${index + 1}. ${contact.name}: ${contact.contact}`);
      });
    }

    console.log("\n💰 Bounty Terms:");
    console.log("  Bounty Percentage:", agreement.bountyTerms.bountyPercentage.toString() + "%");
    console.log("  Bounty Cap USD:", agreement.bountyTerms.bountyCapUsd.toString());
    console.log("  Retainable:", agreement.bountyTerms.retainable);
    console.log("  Identity Requirements:", formatIdentityRequirements(agreement.bountyTerms.identity));
    console.log("  Diligence Requirements:", agreement.bountyTerms.diligenceRequirements);
    console.log("  Aggregate Bounty Cap USD:", agreement.bountyTerms.aggregateBountyCapUsd.toString());

    console.log("\n🔗 Chains and Accounts:");
    if (agreement.chains.length === 0) {
      console.log("  No chains specified");
    } else {
      let totalAccounts = 0;
      agreement.chains.forEach((chain, chainIndex) => {
        console.log(`  Chain ${chainIndex + 1}: ${chain.caip2ChainId}`);
        console.log(`    Asset Recovery Address: ${chain.assetRecoveryAddress}`);
        console.log(`    Accounts (${chain.accounts.length}):`);
        totalAccounts += chain.accounts.length;

        if (chain.accounts.length === 0) {
          console.log("      No accounts specified");
        } else {
          chain.accounts.forEach((account, accountIndex) => {
            console.log(`      ${accountIndex + 1}. ${account.accountAddress}`);
            console.log(`         Child Contract Scope: ${formatChildContractScope(account.childContractScope)}`);
          });
        }
      });

      console.log(`\n📊 Summary: ${agreement.chains.length} chains, ${totalAccounts} total accounts`);
    }

    // Check adoption status using adopter-keyed PDA (preferred)
    console.log("\n🤝 Checking Adoption Status...");
    try {
      const adopter = provider.wallet.publicKey;
      const [adoptionHead] = PublicKey.findProgramAddressSync(
        [Buffer.from("adoption_head"), adopter.toBuffer()],
        program.programId
      );
      const adoptedAgreement = await program.methods
        .getAgreementForAdopter()
        .accountsPartial({ adopter, adoptionHead })
        .view();

      if (adoptedAgreement.toString() === agreementPubkey.toString()) {
        console.log("  ✅ Adopted by current wallet:", adopter.toString());
      } else {
        console.log("  ❌ Current wallet adopted a different agreement:", adoptedAgreement.toString());
      }
    } catch (error) {
      console.log("  ❌ No adoption record found for current wallet");
    }

    // Save details to JSON file
    const detailsOutput = {
      address: agreementPubkey.toString(),
      owner: agreement.owner.toString(),
      protocolName: agreement.protocolName,
      agreementUri: agreement.agreementUri,
      contactDetails: agreement.contactDetails,
      bountyTerms: {
        bountyPercentage: agreement.bountyTerms.bountyPercentage.toString(),
        bountyCapUsd: agreement.bountyTerms.bountyCapUsd.toString(),
        retainable: agreement.bountyTerms.retainable,
        identity: formatIdentityRequirements(agreement.bountyTerms.identity),
        diligenceRequirements: agreement.bountyTerms.diligenceRequirements,
        aggregateBountyCapUsd: agreement.bountyTerms.aggregateBountyCapUsd.toString(),
      },
      chains: agreement.chains.map(chain => ({
        caip2ChainId: chain.caip2ChainId,
        assetRecoveryAddress: chain.assetRecoveryAddress,
        accounts: chain.accounts.map(account => ({
          accountAddress: account.accountAddress,
          childContractScope: formatChildContractScope(account.childContractScope),
        })),
      })),
      queriedAt: new Date().toISOString(),
    };

    const outputFile = `./agreement-details-${agreementPubkey.toString().slice(0, 8)}.json`;
    fs.writeFileSync(outputFile, JSON.stringify(detailsOutput, null, 2));
    console.log(`\n📄 Details saved to: ${outputFile}`);

  } catch (error) {
    console.error("❌ Error fetching agreement details:", error);
    if (error.message?.includes("Account does not exist")) {
      console.log("💡 Make sure the agreement address is correct and the account exists");
    }
    process.exit(1);
  }
}

function formatIdentityRequirements(identity: any): string {
  if (identity.anonymous !== undefined) return "Anonymous";
  if (identity.pseudonymous !== undefined) return "Pseudonymous";
  if (identity.named !== undefined) return "Named";
  return "Unknown";
}

function formatChildContractScope(scope: any): string {
  if (scope.none !== undefined) return "None";
  if (scope.existingOnly !== undefined) return "Existing Only";
  if (scope.all !== undefined) return "All";
  if (scope.futureOnly !== undefined) return "Future Only";
  return "Unknown";
}

main().catch((error) => {
  console.error("❌ Failed to get agreement details:", error);
  process.exit(1);
});
