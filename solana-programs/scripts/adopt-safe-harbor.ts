import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";
const AGREEMENT_DATA_PATH =
  process.env.AGREEMENT_DATA_PATH || "./agreement-details.json";
const ADOPTER_KEYPAIR_PATH =
  process.env.ADOPTER_KEYPAIR_PATH || "./adopter-keypair.json";

interface AgreementDetails {
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
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

  console.log("🤝 Adopting Safe Harbor Agreement");

  // Load deployment info
  const deploymentInfo = JSON.parse(
    fs.readFileSync(DEPLOYMENT_INFO_PATH, "utf8")
  );
  const registryPda = new PublicKey(deploymentInfo.registryPda);

  console.log("Registry PDA:", registryPda.toString());

  // Load or generate adopter keypair
  let adopterKeypair: Keypair;
  try {
    const adopterKeypairData = JSON.parse(
      fs.readFileSync(ADOPTER_KEYPAIR_PATH, "utf8")
    );
    adopterKeypair = Keypair.fromSecretKey(new Uint8Array(adopterKeypairData));
    console.log("Loaded adopter keypair from:", ADOPTER_KEYPAIR_PATH);
  } catch (error) {
    console.log("Generating new adopter keypair...");
    adopterKeypair = Keypair.generate();
    fs.writeFileSync(
      ADOPTER_KEYPAIR_PATH,
      JSON.stringify(Array.from(adopterKeypair.secretKey))
    );
    console.log("Saved adopter keypair to:", ADOPTER_KEYPAIR_PATH);
  }

  console.log("Adopter address:", adopterKeypair.publicKey.toString());

  // Load agreement details
  let agreementDetails: AgreementDetails;
  try {
    agreementDetails = JSON.parse(fs.readFileSync(AGREEMENT_DATA_PATH, "utf8"));
    console.log("Loaded agreement details from:", AGREEMENT_DATA_PATH);
  } catch (error) {
    console.log("Creating sample agreement details...");
    agreementDetails = createSampleAgreementDetails();
    fs.writeFileSync(
      AGREEMENT_DATA_PATH,
      JSON.stringify(agreementDetails, null, 2)
    );
    console.log("Saved sample agreement details to:", AGREEMENT_DATA_PATH);
  }

  console.log("Protocol Name:", agreementDetails.protocolName);

  // Create agreement account
  const agreementKeypair = Keypair.generate();
  console.log("Agreement address:", agreementKeypair.publicKey.toString());

  // Convert agreement details to program format
  const rawData = agreementDetails as any; // Handle different JSON formats
  
  const params = {
    protocolName: rawData.protocolName,
    contactDetails: (rawData.contactDetails || rawData.contact || []).map((c: any) => ({
      name: c.contactType || c.name || "Contact",
      contact: c.contact,
    })),
    chains: (rawData.chains || []).map((chain: any) => ({
      assetRecoveryAddress: chain.assetRecoveryAddress || "0x742d35Cc6634C0532925a3b8D400e4C053292",
      accounts: (chain.accounts || []).map((acc: any) => ({
        accountAddress: acc.accountAddress,
        childContractScope: { none: {} }, // Convert enum
      })),
      caip2ChainId: chain.caip2ChainId || chain.id,
    })),
    bountyTerms: {
      bountyPercentage: new anchor.BN(rawData.bountyTerms.bountyPercentage),
      bountyCapUsd: new anchor.BN(rawData.bountyTerms.bountyCapUsd || rawData.bountyTerms.bountyCapUSD || 100000),
      retainable: rawData.bountyTerms.retainable,
      identity: { anonymous: {} }, // Convert enum
      diligenceRequirements: rawData.bountyTerms.diligenceRequirements || "Standard security review",
      aggregateBountyCapUsd: new anchor.BN(rawData.bountyTerms.aggregateBountyCapUsd || rawData.bountyTerms.aggregateBountyCapUSD || 0),
    },
    agreementUri: rawData.agreementUri || rawData.agreementURI || "https://example.com/agreement",
  };

  console.log("📝 Creating and adopting agreement in one transaction...");

  try {
    const createAndAdoptTx = await program.methods
      .createAndAdoptAgreement(params)
      .accountsPartial({
        registry: registryPda,
        agreement: agreementKeypair.publicKey,
        owner: provider.wallet.publicKey,
        adopter: adopterKeypair.publicKey,
        payer: provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([agreementKeypair, adopterKeypair])
      .rpc();

    console.log("✅ Agreement created and adopted!");
    console.log("Transaction signature:", createAndAdoptTx);
  } catch (error) {
    console.error("❌ Error creating and adopting agreement:", error);
    console.error("Full error details:", JSON.stringify(error, null, 2));
    return;
  }

  // Save adoption info
  const adoptionInfo = {
    adopter: adopterKeypair.publicKey.toString(),
    agreement: agreementKeypair.publicKey.toString(),
    protocolName: agreementDetails.protocolName,
    adoptedAt: new Date().toISOString(),
  };

  fs.writeFileSync(
    "./adoption-info.json",
    JSON.stringify(adoptionInfo, null, 2)
  );

  console.log("\n🎉 Adoption Summary:");
  console.log("=".repeat(50));
  console.log("Adopter:", adopterKeypair.publicKey.toString());
  console.log("Agreement:", agreementKeypair.publicKey.toString());
  console.log("Protocol:", agreementDetails.protocolName);
  console.log("📄 Adoption info saved to adoption-info.json");
}

function createSampleAgreementDetails(): AgreementDetails {
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
  console.error("❌ Adoption failed:", error);
  process.exit(1);
});
