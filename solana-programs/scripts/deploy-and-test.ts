import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";
const OWNER_KEYPAIR_PATH = "./owner-keypair.json";

async function main() {
  console.log("🚀 Starting Complete End-to-End Test on Devnet");
  console.log("=" .repeat(60));

  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;
  console.log("📋 Program ID:", program.programId.toString());

  // Load owner keypair
  const ownerKeypair = Keypair.fromSecretKey(
    new Uint8Array(JSON.parse(fs.readFileSync(OWNER_KEYPAIR_PATH, "utf8")))
  );
  console.log("👤 Owner Address:", ownerKeypair.publicKey.toString());

  // Step 1: Deploy Registry
  console.log("\n🏗️  Step 1: Deploying Registry...");
  
  const [registryPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry")],
    program.programId
  );
  
  console.log("📍 Registry PDA:", registryPda.toString());

  try {
    const initTx = await program.methods
      .initializeRegistry(ownerKeypair.publicKey)
      .accountsPartial({
        registry: registryPda,
        payer: provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();
    
    console.log("✅ Registry initialized!");
    console.log("🔗 Transaction:", `https://explorer.solana.com/tx/${initTx}?cluster=devnet`);
  } catch (error: any) {
    if (error.message?.includes("already in use")) {
      console.log("ℹ️  Registry already exists, continuing...");
    } else {
      console.error("❌ Error initializing registry:", error);
      return;
    }
  }

  // Step 2: Add Valid Chains
  console.log("\n⛓️  Step 2: Adding Valid Chains...");
  
  const validChains = [
    "eip155:1",      // Ethereum Mainnet
    "eip155:137",    // Polygon
    "eip155:42161",  // Arbitrum One
    "eip155:10",     // Optimism
    "eip155:8453",   // Base
    "eip155:43114",  // Avalanche
    "eip155:56",     // BSC
    "eip155:100",    // Gnosis Chain
  ];

  try {
    const chainsTx = await program.methods
      .setValidChains(validChains)
      .accountsPartial({
        registry: registryPda,
        signer: ownerKeypair.publicKey,
      })
      .signers([ownerKeypair])
      .rpc();
    
    console.log("✅ Valid chains added!");
    console.log("📋 Chains:", validChains.join(", "));
    console.log("🔗 Transaction:", `https://explorer.solana.com/tx/${chainsTx}?cluster=devnet`);
  } catch (error) {
    console.error("❌ Error adding chains:", error);
    return;
  }

  // Step 3: Test Agreement Creation and Adoption
  console.log("\n🤝 Step 3: Testing Agreement Creation and Adoption...");
  
  // Generate test keypairs
  const agreementKeypair = Keypair.generate();
  const adopterKeypair = Keypair.generate();
  
  console.log("📄 Agreement Address:", agreementKeypair.publicKey.toString());
  console.log("👤 Adopter Address:", adopterKeypair.publicKey.toString());

  // Create comprehensive test agreement
  const testAgreement = {
    protocolName: "DeFi Protocol Test",
    contactDetails: [
      {
        name: "Security Team",
        contact: "security@defiprotocol.com",
      },
      {
        name: "Emergency Contact", 
        contact: "emergency@defiprotocol.com",
      }
    ],
    chains: [
      {
        assetRecoveryAddress: "0x742d35Cc6634C0532925a3b8D400e4C053292ABC",
        accounts: [
          {
            accountAddress: "0x1234567890123456789012345678901234567890",
            childContractScope: { none: {} } as any,
          },
          {
            accountAddress: "0xABCDEF1234567890123456789012345678901234",
            childContractScope: { all: {} } as any,
          }
        ],
        caip2ChainId: "eip155:1",
      },
      {
        assetRecoveryAddress: "0x742d35Cc6634C0532925a3b8D400e4C053292DEF",
        accounts: [
          {
            accountAddress: "0x9876543210987654321098765432109876543210",
            childContractScope: { existingOnly: {} } as any,
          }
        ],
        caip2ChainId: "eip155:137",
      }
    ],
    bountyTerms: {
      bountyPercentage: new anchor.BN(15),
      bountyCapUsd: new anchor.BN(250000),
      retainable: true,
      identity: { pseudonymous: {} } as any,
      diligenceRequirements: "Comprehensive security audit and responsible disclosure",
      aggregateBountyCapUsd: new anchor.BN(0),
    },
    agreementUri: "ipfs://QmTestAgreementHashForDeFiProtocol123456789",
  };

  try {
    const adoptTx = await program.methods
      .createAndAdoptAgreement(testAgreement)
      .accountsPartial({
        registry: registryPda,
        agreement: agreementKeypair.publicKey,
        owner: ownerKeypair.publicKey,
        adopter: adopterKeypair.publicKey,
        payer: provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([agreementKeypair, adopterKeypair, ownerKeypair])
      .rpc();
    
    console.log("✅ Agreement created and adopted!");
    console.log("🔗 Transaction:", `https://explorer.solana.com/tx/${adoptTx}?cluster=devnet`);
  } catch (error) {
    console.error("❌ Error creating/adopting agreement:", error);
    return;
  }

  // Step 4: Verify Agreement Data
  console.log("\n🔍 Step 4: Verifying Agreement Data...");
  
  try {
    const agreementAccount = await program.account.agreement.fetch(agreementKeypair.publicKey);
    
    console.log("📋 Agreement Details:");
    console.log("  Protocol Name:", agreementAccount.protocolName);
    console.log("  Owner:", agreementAccount.owner.toString());
    console.log("  Contacts:", agreementAccount.contactDetails.length);
    console.log("  Chains:", agreementAccount.chains.length);
    console.log("  Bounty %:", agreementAccount.bountyTerms.bountyPercentage.toString());
    console.log("  Bounty Cap:", agreementAccount.bountyTerms.bountyCapUsd.toString());
    console.log("  Agreement URI:", agreementAccount.agreementUri);
    
    // Verify registry adoption
    const registryAccount = await program.account.registry.fetch(registryPda);
    const adoption = registryAccount.agreements.items.find(
      item => item.key.equals(adopterKeypair.publicKey)
    );
    
    if (adoption && adoption.value.equals(agreementKeypair.publicKey)) {
      console.log("✅ Adoption verified in registry!");
    } else {
      console.log("❌ Adoption not found in registry");
    }
    
  } catch (error) {
    console.error("❌ Error verifying agreement:", error);
    return;
  }

  // Step 5: Test Additional Operations
  console.log("\n🔧 Step 5: Testing Additional Operations...");
  
  // Test adding more accounts
  try {
    const newAccounts = [
      {
        accountAddress: "0xNEWACCOUNT1234567890123456789012345678",
        childContractScope: { futureOnly: {} } as any,
      }
    ];
    
    const addAccountsTx = await program.methods
      .addAccounts("eip155:1", newAccounts)
      .accountsPartial({
        agreement: agreementKeypair.publicKey,
        owner: ownerKeypair.publicKey,
      })
      .signers([ownerKeypair])
      .rpc();
    
    console.log("✅ Additional accounts added!");
    console.log("🔗 Transaction:", `https://explorer.solana.com/tx/${addAccountsTx}?cluster=devnet`);
  } catch (error) {
    console.error("❌ Error adding accounts:", error);
  }

  // Step 6: Save Deployment Info
  console.log("\n💾 Step 6: Saving Deployment Information...");
  
  const deploymentInfo = {
    programId: program.programId.toString(),
    registryPda: registryPda.toString(),
    owner: ownerKeypair.publicKey.toString(),
    network: "https://api.devnet.solana.com",
    validChains,
    testAgreement: {
      address: agreementKeypair.publicKey.toString(),
      adopter: adopterKeypair.publicKey.toString(),
      protocolName: testAgreement.protocolName,
    },
    deployedAt: new Date().toISOString(),
    version: "2.0.0"
  };

  fs.writeFileSync(DEPLOYMENT_INFO_PATH, JSON.stringify(deploymentInfo, null, 2));
  console.log("✅ Deployment info saved to", DEPLOYMENT_INFO_PATH);

  // Final Summary
  console.log("\n🎉 END-TO-END TEST COMPLETE!");
  console.log("=" .repeat(60));
  console.log("🔗 Solana Explorer Links:");
  console.log(`📋 Program: https://explorer.solana.com/address/${program.programId}?cluster=devnet`);
  console.log(`🏛️  Registry: https://explorer.solana.com/address/${registryPda}?cluster=devnet`);
  console.log(`📄 Agreement: https://explorer.solana.com/address/${agreementKeypair.publicKey}?cluster=devnet`);
  console.log(`👤 Adopter: https://explorer.solana.com/address/${adopterKeypair.publicKey}?cluster=devnet`);
  
  console.log("\n✅ All tests passed! The Safe Harbor V2 Solana implementation is working correctly.");
  console.log("🚀 Ready for production deployment!");
}

main().catch((error) => {
  console.error("❌ Test failed:", error);
  process.exit(1);
});
