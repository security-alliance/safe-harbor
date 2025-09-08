import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";
const AGREEMENT_DATA_PATH = process.argv[2] || process.env.AGREEMENT_DATA_PATH || "./agreement-data.json";
const OWNER_KEYPAIR_PATH = process.env.OWNER_KEYPAIR_PATH || "./agreement-owner-keypair.json";
const SHOULD_ADOPT = process.env.SHOULD_ADOPT === "true";

interface AgreementDetailsJSON {
  protocolName: string;
  contact: Array<{
    name: string;
    contact: string;
  }>;
  chains: Array<{
    id: string;
    assetRecoveryAddress: string;
    accounts: Array<{
      accountAddress: string;
      childContractScope: number;
    }>;
  }>;
  bountyTerms: {
    bountyPercentage: number;
    bountyCapUSD: number;
    retainable: boolean;
    identity: number;
    diligenceRequirements: string;
    aggregateBountyCapUSD: number;
  };
  agreementURI: string;
}

async function main() {
  // Check for help flag
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    console.log(`
🤝 Safe Harbor Agreement Creator

Usage:
  npx ts-node scripts/adopt-agreement.ts [agreement-data.json]
  npx ts-node scripts/adopt-agreement.ts --help

Arguments:
  agreement-data.json    Path to JSON file with agreement details (default: ./agreement-data.json)

Environment Variables:
  SHOULD_ADOPT=true     Also adopt the agreement after creating it
  OWNER_KEYPAIR_PATH    Path to agreement owner keypair (default: ./agreement-owner-keypair.json)

Examples:
  npx ts-node scripts/adopt-agreement.ts
  npx ts-node scripts/adopt-agreement.ts my-protocol.json
  SHOULD_ADOPT=true npx ts-node scripts/adopt-agreement.ts custom-agreement.json
    `);
    return;
  }

  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

  console.log("🤝 Creating Safe Harbor Agreement");
  console.log("Agreement data file:", AGREEMENT_DATA_PATH);

  // Derive registry PDA directly (don't depend on deployment info)
  const [registryPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry")],
    program.programId
  );
  console.log("Registry PDA:", registryPda.toString());

  // Load or generate agreement owner keypair
  let ownerKeypair: Keypair;
  try {
    const ownerKeypairData = JSON.parse(fs.readFileSync(OWNER_KEYPAIR_PATH, "utf8"));
    ownerKeypair = Keypair.fromSecretKey(new Uint8Array(ownerKeypairData));
    console.log("Loaded agreement owner keypair from:", OWNER_KEYPAIR_PATH);
  } catch (error) {
    console.log("Generating new agreement owner keypair...");
    ownerKeypair = Keypair.generate();
    fs.writeFileSync(
      OWNER_KEYPAIR_PATH,
      JSON.stringify(Array.from(ownerKeypair.secretKey))
    );
    console.log("Saved agreement owner keypair to:", OWNER_KEYPAIR_PATH);
  }

  console.log("Agreement owner:", ownerKeypair.publicKey.toString());

  // Load agreement details
  if (!fs.existsSync(AGREEMENT_DATA_PATH)) {
    console.log("Creating sample agreement details...");
    const sampleDetails = createSampleAgreementDetails();
    fs.writeFileSync(
      AGREEMENT_DATA_PATH,
      JSON.stringify(sampleDetails, null, 2)
    );
    console.log("📄 Sample agreement details saved to:", AGREEMENT_DATA_PATH);
    console.log("Please edit this file with your protocol details and run the script again.");
    return;
  }

  const agreementDetails: AgreementDetailsJSON = JSON.parse(
    fs.readFileSync(AGREEMENT_DATA_PATH, "utf8")
  );
  console.log("Loaded agreement details from:", AGREEMENT_DATA_PATH);
  console.log("Protocol Name:", agreementDetails.protocolName);

  // Create agreement account
  const agreementKeypair = Keypair.generate();
  console.log("Agreement address:", agreementKeypair.publicKey.toString());

  // Convert agreement details to program format
  const params: any = {
    protocolName: agreementDetails.protocolName,
    contactDetails: agreementDetails.contact.map((c) => ({
      name: c.name,
      contact: c.contact,
    })),
    chains: agreementDetails.chains.map((chain) => ({
      assetRecoveryAddress: chain.assetRecoveryAddress,
      accounts: chain.accounts.map((acc) => ({
        accountAddress: acc.accountAddress,
        childContractScope: convertChildContractScope(acc.childContractScope),
      })),
      caip2ChainId: chain.id,
    })),
    bountyTerms: {
      bountyPercentage: new anchor.BN(agreementDetails.bountyTerms.bountyPercentage),
      bountyCapUsd: new anchor.BN(agreementDetails.bountyTerms.bountyCapUSD),
      retainable: agreementDetails.bountyTerms.retainable,
      identity: convertIdentityRequirements(agreementDetails.bountyTerms.identity),
      diligenceRequirements: agreementDetails.bountyTerms.diligenceRequirements,
      aggregateBountyCapUsd: new anchor.BN(agreementDetails.bountyTerms.aggregateBountyCapUSD),
    },
    agreementUri: agreementDetails.agreementURI,
  };

  // First create the agreement with minimal data
  const minimalParams = {
    ...params,
    // Start with empty accounts to avoid transaction size issues
    chains: params.chains.map(chain => ({
      ...chain,
      accounts: []
    }))
  };

  if (SHOULD_ADOPT) {
    console.log("📝 Creating and adopting agreement (without accounts first)...");
    
    try {
      const createAndAdoptTx = await program.methods
        .createAndAdoptAgreement(minimalParams)
        .accountsPartial({
          registry: registryPda,
          agreement: agreementKeypair.publicKey,
          owner: ownerKeypair.publicKey,
          adopter: provider.wallet.publicKey, // Deployer adopts the agreement
          payer: provider.wallet.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([agreementKeypair, ownerKeypair])
        .rpc();

      console.log("✅ Agreement created and adopted!");
      console.log("Transaction signature:", createAndAdoptTx);

      // Now add accounts in batches
      console.log("📝 Adding accounts in batches...");
      const BATCH_SIZE = 5; // Adjust based on your needs
      
      for (const chain of params.chains) {
        if (chain.accounts.length === 0) continue;
        
        console.log(`  Adding ${chain.accounts.length} accounts for chain ${chain.caip2ChainId}...`);
        
        for (let i = 0; i < chain.accounts.length; i += BATCH_SIZE) {
          const batch = chain.accounts.slice(i, i + BATCH_SIZE);
          console.log(`    Adding batch ${i / BATCH_SIZE + 1} (${batch.length} accounts)...`);
          
          try {
            const addTx = await program.methods
              .addAccounts(chain.caip2ChainId, batch)
              .accounts({
                agreement: agreementKeypair.publicKey,
                owner: ownerKeypair.publicKey,
              })
              .signers([ownerKeypair])
              .rpc();
              
            console.log(`    ✅ Batch ${i / BATCH_SIZE + 1} added:`, addTx);
          } catch (error) {
            console.error(`    ❌ Error adding batch ${i / BATCH_SIZE + 1}:`, error);
            throw error; // Rethrow to be caught by outer try-catch
          }
        }
      }
      
    } catch (error) {
      console.error("❌ Error creating and adopting agreement:", error);
      return;
    }
  } else {
    console.log("📝 Creating agreement (without accounts first)...");
    
    try {
      const createTx = await program.methods
        .createAgreement(minimalParams)
        .accountsPartial({
          registry: registryPda,
          agreement: agreementKeypair.publicKey,
          owner: ownerKeypair.publicKey,
          payer: provider.wallet.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([agreementKeypair, ownerKeypair])
        .rpc();

      console.log("✅ Agreement created!");
      console.log("Transaction signature:", createTx);

      // Now add accounts in batches
      console.log("📝 Adding accounts in batches...");
      const BATCH_SIZE = 5; // Adjust based on your needs
      
      for (const chain of params.chains) {
        if (chain.accounts.length === 0) continue;
        
        console.log(`  Adding ${chain.accounts.length} accounts for chain ${chain.caip2ChainId}...`);
        
        for (let i = 0; i < chain.accounts.length; i += BATCH_SIZE) {
          const batch = chain.accounts.slice(i, i + BATCH_SIZE);
          console.log(`    Adding batch ${i / BATCH_SIZE + 1} (${batch.length} accounts)...`);
          
          try {
            const addTx = await program.methods
              .addAccounts(chain.caip2ChainId, batch)
              .accounts({
                agreement: agreementKeypair.publicKey,
                owner: ownerKeypair.publicKey,
              })
              .signers([ownerKeypair])
              .rpc();
              
            console.log(`    ✅ Batch ${i / BATCH_SIZE + 1} added:`, addTx);
          } catch (error) {
            console.error(`    ❌ Error adding batch ${i / BATCH_SIZE + 1}:`, error);
            throw error; // Rethrow to be caught by outer try-catch
          }
        }
      }
      
      console.log("💡 To adopt this agreement, use the adopt-safe-harbor.ts script");
    } catch (error) {
      console.error("❌ Error creating agreement:", error);
      return;
    }
  }

  // Save agreement info
  const agreementInfo = {
    agreement: agreementKeypair.publicKey.toString(),
    owner: ownerKeypair.publicKey.toString(),
    protocolName: agreementDetails.protocolName,
    adopted: SHOULD_ADOPT,
    adopter: SHOULD_ADOPT ? provider.wallet.publicKey.toString() : null,
    createdAt: new Date().toISOString(),
  };

  fs.writeFileSync(
    "./agreement-info.json",
    JSON.stringify(agreementInfo, null, 2)
  );

  console.log("\n🎉 Agreement Summary:");
  console.log("=".repeat(50));
  console.log("Agreement:", agreementKeypair.publicKey.toString());
  console.log("Owner:", ownerKeypair.publicKey.toString());
  console.log("Protocol:", agreementDetails.protocolName);
  console.log("Chains:", agreementDetails.chains.length);
  console.log("Accounts:", agreementDetails.chains.reduce((sum, chain) => sum + chain.accounts.length, 0));
  if (SHOULD_ADOPT) {
    console.log("Adopter:", provider.wallet.publicKey.toString());
  }
  console.log("📄 Agreement info saved to agreement-info.json");
}

function convertChildContractScope(scope: number): any {
  switch (scope) {
    case 0: return { none: {} };
    case 1: return { existingOnly: {} };
    case 2: return { all: {} };
    case 3: return { futureOnly: {} };
    default: return { none: {} };
  }
}

function convertIdentityRequirements(identity: number): any {
  switch (identity) {
    case 0: return { anonymous: {} };
    case 1: return { pseudonymous: {} };
    case 2: return { named: {} };
    default: return { anonymous: {} };
  }
}

function createSampleAgreementDetails(): AgreementDetailsJSON {
  return {
    protocolName: "Sample DeFi Protocol",
    contact: [
      {
        name: "Security Team",
        contact: "security@sampledefi.com",
      },
    ],
    chains: [
      {
        id: "eip155:1",
        assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
        accounts: [
          {
            accountAddress: "0x1234567890123456789012345678901234567890",
            childContractScope: 0, // None
          },
        ],
      },
    ],
    bountyTerms: {
      bountyPercentage: 10,
      bountyCapUSD: 100000,
      retainable: true,
      identity: 0, // Anonymous
      diligenceRequirements: "Standard security review and disclosure process",
      aggregateBountyCapUSD: 0,
    },
    agreementURI: "ipfs://QmSampleAgreementHash",
  };
}

main().catch((error) => {
  console.error("❌ Agreement creation failed:", error);
  process.exit(1);
});
