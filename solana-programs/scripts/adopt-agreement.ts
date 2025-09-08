import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair, SystemProgram, Transaction, LAMPORTS_PER_SOL } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";
const AGREEMENT_DATA_PATH = process.argv[2] || process.env.AGREEMENT_DATA_PATH || "./agreement-data.json";
const OWNER_KEYPAIR_PATH = process.env.OWNER_KEYPAIR_PATH || "./agreement-owner-keypair.json";
const SHOULD_ADOPT = process.env.SHOULD_ADOPT !== "false"; // Default to true for better UX

// All supported chains from deploy-and-set-chains.ts - MUST match exactly
const VALID_CHAINS = [
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
🤝 Safe Harbor Agreement Creator (Production Ready)

Usage:
  npx ts-node scripts/adopt-agreement.ts [agreement-data.json]
  npx ts-node scripts/adopt-agreement.ts --help

Arguments:
  agreement-data.json    Path to JSON file with agreement details (default: ./agreement-data.json)

Environment Variables:
  SHOULD_ADOPT=false         Set to false to skip adoption (default: true)
  OWNER_KEYPAIR_PATH         Path to agreement owner keypair (default: ./agreement-owner-keypair.json)
  PREFUND_AGREEMENT_SOL      SOL to prefund for rent (auto-calculated if not set)

Features:
  ✅ Validates chains against registry (skips invalid chains)
  ✅ Handles duplicate chains by merging accounts
  ✅ Progressive creation for large agreements (>10 chains or >50 accounts)
  ✅ Smart rent estimation and prefunding
  ✅ Comprehensive error handling and reporting

Examples:
  # Standard usage (auto-adopts by default)
  npx ts-node scripts/adopt-agreement.ts my-protocol.json
  
  # Large protocol with 50 chains (uses progressive strategy)
  npx ts-node scripts/adopt-agreement.ts agreement-data-sample.json
  
  # Custom prefunding for large agreements
  PREFUND_AGREEMENT_SOL=5 npx ts-node scripts/adopt-agreement.ts large-protocol.json
  
  # Create without adopting
  SHOULD_ADOPT=false npx ts-node scripts/adopt-agreement.ts my-protocol.json

Large Agreement Support:
  Automatically handles agreements with many chains using progressive creation:
  1. Creates agreement with initial chains (no accounts)
  2. Adds remaining chains in batches via add_chains()
  3. Adds all accounts in batches via add_accounts()
  
  Supports all 50 chains from the registry when properly funded.
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

  // Validate registry exists and get valid chains
  try {
    const registryData = await program.account.registry.fetch(registryPda);
    console.log("✅ Registry found with", registryData.validChains.length, "valid chains");
  } catch (error) {
    console.error("❌ Registry not found. Please run deployment first:");
    console.error("  npm run deploy");
    return;
  }

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

  // Validate chains against registry and filter to only valid ones
  const validAgreementChains = agreementDetails.chains.filter(chain => {
    const isValid = VALID_CHAINS.includes(chain.id);
    if (!isValid) {
      console.log(`⚠️  Skipping invalid chain: ${chain.id} (not in registry)`);
    }
    return isValid;
  });

  // Handle duplicates by merging accounts
  const chainMap = new Map();
  validAgreementChains.forEach(chain => {
    if (chainMap.has(chain.id)) {
      // Merge accounts for duplicate chains
      const existing = chainMap.get(chain.id);
      existing.accounts.push(...chain.accounts);
      console.log(`🔄 Merged duplicate chain: ${chain.id} (${chain.accounts.length} additional accounts)`);
    } else {
      chainMap.set(chain.id, { ...chain });
    }
  });

  const processedChains = Array.from(chainMap.values());
  const totalAccounts = processedChains.reduce((sum, chain) => sum + chain.accounts.length, 0);

  console.log("📊 Agreement Analysis:");
  console.log(`  Valid chains: ${processedChains.length}/${agreementDetails.chains.length}`);
  console.log(`  Total accounts: ${totalAccounts}`);
  console.log(`  Estimated rent needed: ${Math.ceil(totalAccounts / 20)} SOL`);

  if (processedChains.length === 0) {
    console.error("❌ No valid chains found in agreement data");
    console.error("   Please ensure chain IDs match those in deploy-and-set-chains.ts");
    return;
  }

  // Create agreement account
  const agreementKeypair = Keypair.generate();
  console.log("Agreement address:", agreementKeypair.publicKey.toString());

  // Convert agreement details to program format using processed chains
  const params: any = {
    protocolName: agreementDetails.protocolName,
    contactDetails: agreementDetails.contact.map((c) => ({
      name: c.name,
      contact: c.contact,
    })),
    chains: processedChains.map((chain) => ({
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

  // Progressive creation strategy for large agreements
  const isLargeAgreement = processedChains.length > 10 || totalAccounts > 50;

  if (isLargeAgreement) {
    console.log("📈 Large agreement detected - using progressive creation strategy");
    console.log(`   ${processedChains.length} chains, ${totalAccounts} accounts`);
  }

  // Start with first few chains only (no accounts initially)
  const initialChainsCount = isLargeAgreement ? Math.min(3, processedChains.length) : processedChains.length;
  const minimalParams = {
    ...params,
    chains: params.chains.slice(0, initialChainsCount).map(chain => ({
      ...chain,
      accounts: [] // Start with no accounts
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

      // Smart prefunding based on agreement size
      const estimatedRentSol = Math.max(0.1, Math.ceil(totalAccounts / 20));
      const prefundSol = Number(process.env.PREFUND_AGREEMENT_SOL || estimatedRentSol.toString());

      if (prefundSol > 0) {
        try {
          console.log(`💸 Prefunding agreement account with ${prefundSol} SOL for rent...`);
          const transferIx = SystemProgram.transfer({
            fromPubkey: ownerKeypair.publicKey,
            toPubkey: agreementKeypair.publicKey,
            lamports: Math.floor(prefundSol * LAMPORTS_PER_SOL),
          });
          const tx = new Transaction().add(transferIx);
          const sig = await provider.sendAndConfirm(tx, [ownerKeypair]);
          console.log("  ✅ Prefund tx:", sig);
        } catch (prefundErr) {
          console.log("  ⚠️  Prefund failed (continuing):", (prefundErr as Error).message);
          console.log("     Agreement may fail during account additions if insufficient rent");
        }
      }

      // Add remaining chains progressively (if large agreement)
      if (isLargeAgreement && processedChains.length > initialChainsCount) {
        const remainingChains = params.chains.slice(initialChainsCount);
        console.log(`🔗 Adding ${remainingChains.length} remaining chains progressively...`);

        const CHAIN_BATCH_SIZE = 5;
        for (let i = 0; i < remainingChains.length; i += CHAIN_BATCH_SIZE) {
          const batch = remainingChains.slice(i, i + CHAIN_BATCH_SIZE).map(chain => ({
            ...chain,
            accounts: [] // Add chains without accounts first
          }));

          console.log(`  Adding batch ${Math.floor(i / CHAIN_BATCH_SIZE) + 1}: ${batch.map(c => c.caip2ChainId).join(', ')}`);

          try {
            const addChainsTx = await program.methods
              .addChains(batch)
              .accountsPartial({
                registry: registryPda,
                agreement: agreementKeypair.publicKey,
                owner: ownerKeypair.publicKey,
              })
              .signers([ownerKeypair])
              .rpc();

            console.log(`    ✅ Added ${batch.length} chains`);
          } catch (error) {
            console.error(`    ❌ Error adding chain batch:`, error);
            // Continue with account additions even if some chains failed
          }
        }
      }

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

      // Smart prefunding based on agreement size
      const estimatedRentSol = Math.max(0.1, Math.ceil(totalAccounts / 20));
      const prefundSol = Number(process.env.PREFUND_AGREEMENT_SOL || estimatedRentSol.toString());

      if (prefundSol > 0) {
        try {
          console.log(`💸 Prefunding agreement account with ${prefundSol} SOL for rent...`);
          const transferIx = SystemProgram.transfer({
            fromPubkey: ownerKeypair.publicKey,
            toPubkey: agreementKeypair.publicKey,
            lamports: Math.floor(prefundSol * LAMPORTS_PER_SOL),
          });
          const tx = new Transaction().add(transferIx);
          const sig = await provider.sendAndConfirm(tx, [ownerKeypair]);
          console.log("  ✅ Prefund tx:", sig);
        } catch (prefundErr) {
          console.log("  ⚠️  Prefund failed (continuing):", (prefundErr as Error).message);
          console.log("     Agreement may fail during account additions if insufficient rent");
        }
      }

      // Add remaining chains progressively (if large agreement)
      if (isLargeAgreement && processedChains.length > initialChainsCount) {
        const remainingChains = params.chains.slice(initialChainsCount);
        console.log(`🔗 Adding ${remainingChains.length} remaining chains progressively...`);

        const CHAIN_BATCH_SIZE = 5;
        for (let i = 0; i < remainingChains.length; i += CHAIN_BATCH_SIZE) {
          const batch = remainingChains.slice(i, i + CHAIN_BATCH_SIZE).map(chain => ({
            ...chain,
            accounts: [] // Add chains without accounts first
          }));

          console.log(`  Adding batch ${Math.floor(i / CHAIN_BATCH_SIZE) + 1}: ${batch.map(c => c.caip2ChainId).join(', ')}`);

          try {
            const addChainsTx = await program.methods
              .addChains(batch)
              .accountsPartial({
                registry: registryPda,
                agreement: agreementKeypair.publicKey,
                owner: ownerKeypair.publicKey,
              })
              .signers([ownerKeypair])
              .rpc();

            console.log(`    ✅ Added ${batch.length} chains`);
          } catch (error) {
            console.error(`    ❌ Error adding chain batch:`, error);
            // Continue with account additions even if some chains failed
          }
        }
      }

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

  // Verify final agreement state
  let finalChainsCount = 0;
  let finalAccountsCount = 0;
  try {
    const finalAgreement = await program.account.agreement.fetch(agreementKeypair.publicKey);
    finalChainsCount = finalAgreement.chains.length;
    finalAccountsCount = finalAgreement.chains.reduce((sum, chain) => sum + chain.accounts.length, 0);
  } catch (error) {
    console.log("⚠️  Could not verify final agreement state");
  }

  // Save comprehensive agreement info
  const agreementInfo = {
    agreement: agreementKeypair.publicKey.toString(),
    owner: ownerKeypair.publicKey.toString(),
    protocolName: agreementDetails.protocolName,
    adopted: SHOULD_ADOPT,
    adopter: SHOULD_ADOPT ? provider.wallet.publicKey.toString() : null,
    inputChains: agreementDetails.chains.length,
    validChains: processedChains.length,
    finalChains: finalChainsCount,
    inputAccounts: agreementDetails.chains.reduce((sum, chain) => sum + chain.accounts.length, 0),
    finalAccounts: finalAccountsCount,
    wasLargeAgreement: isLargeAgreement,
    usedProgressiveCreation: isLargeAgreement,
    createdAt: new Date().toISOString(),
  };

  fs.writeFileSync(
    "./agreement-info.json",
    JSON.stringify(agreementInfo, null, 2)
  );

  console.log("\n🎉 Agreement Creation Complete!");
  console.log("=".repeat(60));
  console.log("Agreement:", agreementKeypair.publicKey.toString());
  console.log("Owner:", ownerKeypair.publicKey.toString());
  console.log("Protocol:", agreementDetails.protocolName);
  console.log("Strategy:", isLargeAgreement ? "Progressive (Large Agreement)" : "Standard");
  console.log("Input Chains:", `${agreementDetails.chains.length} → ${processedChains.length} valid`);
  console.log("Final Chains:", finalChainsCount);
  console.log("Final Accounts:", finalAccountsCount);
  if (SHOULD_ADOPT) {
    console.log("Adopter:", provider.wallet.publicKey.toString());
  }

  const success = finalChainsCount === processedChains.length;
  console.log("Status:", success ? "✅ SUCCESS - All chains created!" : `⚠️  PARTIAL - ${finalChainsCount}/${processedChains.length} chains created`);

  console.log("📄 Agreement info saved to agreement-info.json");

  if (!success) {
    console.log("\n💡 For production deployments with many chains:");
    console.log("   • Ensure owner wallet has sufficient SOL for rent");
    console.log("   • Consider using PREFUND_AGREEMENT_SOL environment variable");
    console.log("   • Large agreements are automatically handled progressively");
  }
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
