import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey, Keypair, SystemProgram, Transaction, LAMPORTS_PER_SOL } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";
const AGREEMENT_DATA_PATH = process.argv[2] || process.env.AGREEMENT_DATA_PATH || "./agreement-data.json";
const OWNER_KEYPAIR_PATH = process.env.OWNER_KEYPAIR_PATH || "./agreement-owner-keypair.json";
const OWNER_ADDRESS = process.env.OWNER_ADDRESS || process.argv[3]; // Optional: specify owner address directly
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
  npx ts-node scripts/adopt-agreement.ts [agreement-data.json] [owner-address]
  npx ts-node scripts/adopt-agreement.ts --help

Arguments:
  agreement-data.json    Path to JSON file with agreement details (default: ./agreement-data.json)
  owner-address          Public key of the agreement owner (optional, overrides keypair)

Environment Variables:
  SHOULD_ADOPT=false         Set to false to skip adoption (default: true)
  OWNER_KEYPAIR_PATH         Path to agreement owner keypair (default: ./agreement-owner-keypair.json)
  OWNER_ADDRESS              Public key of the agreement owner (alternative to keypair)
  PREFUND_AGREEMENT_SOL      SOL to prefund for rent (auto-calculated if not set)

Owner Address Mode (EVM-like):
  ✅ Can create simple agreements (≤1 chain, ≤5 accounts) with any owner address
  ❌ Cannot create large agreements (requires progressive creation with owner signatures)
  ❌ Cannot prefund agreements (requires owner to sign transfers)
  ❌ Cannot perform post-creation operations (require owner signature)
  🔑 Deployer signs all transactions, but ownership is assigned to provided address

Features:
  ✅ Validates chains against registry (skips invalid chains)
  ✅ Handles duplicate chains by merging accounts
  ✅ Progressive creation for large agreements (>1 chain or >5 accounts)
  ✅ Smart rent estimation and prefunding
  ✅ Comprehensive error handling and reporting

Examples:
  # Standard usage (auto-adopts by default)
  npx ts-node scripts/adopt-agreement.ts my-protocol.json
  
  # Specify custom owner address (matches EVM behavior!)
  npx ts-node scripts/adopt-agreement.ts my-protocol.json EJL3gUS5G3hA6cEYb8ghZJAvKu2JV19Ef6GBG55XmYf
  
  # Large protocol with 50 chains (requires owner keypair)
  OWNER_KEYPAIR_PATH=./protocol-owner-keypair.json npx ts-node scripts/adopt-agreement.ts agreement-data-sample.json
  
  # Using environment variable for owner address
  OWNER_ADDRESS=EJL3gUS5G3hA6cEYb8ghZJAvKu2JV19Ef6GBG55XmYf npx ts-node scripts/adopt-agreement.ts my-protocol.json
  
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
  const providerWalletSigner = (provider.wallet as any).payer;

  // Ensure adopter (provider wallet) has enough SOL on devnet for rent (adoption PDA, etc.)
  try {
    const url = process.env.ANCHOR_PROVIDER_URL || "";
    const isDevnet = url.includes("devnet");
    if (isDevnet) {
      const bal = await provider.connection.getBalance(provider.wallet.publicKey);
      if (bal < 0.2 * LAMPORTS_PER_SOL) {
        console.log("💧 Airdropping 1 SOL to adopter for rent (devnet)...");
        const sig = await provider.connection.requestAirdrop(provider.wallet.publicKey, 1 * LAMPORTS_PER_SOL);
        await provider.connection.confirmTransaction(sig, "confirmed");
        console.log("  ✅ Airdrop complete");
      }
    }
  } catch (e) {
    console.log("⚠️  Devnet airdrop failed or not available; continuing...");
  }

  console.log("🤝 Creating Safe Harbor Agreement");
  console.log("Agreement data file:", AGREEMENT_DATA_PATH);

  // Derive registry PDA directly (don't depend on deployment info)
  const [registryPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry_v2")],
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

  // Load owner (either keypair for signing or public key only)
  let ownerKeypair: Keypair | null = null;
  let ownerPublicKey: PublicKey;

  if (OWNER_ADDRESS) {
    // Use provided owner address
    try {
      ownerPublicKey = new PublicKey(OWNER_ADDRESS);
      console.log("Using provided owner address:", ownerPublicKey.toString());
      console.log("📝 Note: Deployer will sign all transactions, but agreement will be owned by provided address");
    } catch (error) {
      console.error("❌ Invalid owner address:", OWNER_ADDRESS);
      return;
    }
  } else {
    // Load or generate agreement owner keypair
    try {
      const ownerKeypairData = JSON.parse(fs.readFileSync(OWNER_KEYPAIR_PATH, "utf8"));
      ownerKeypair = Keypair.fromSecretKey(new Uint8Array(ownerKeypairData));
      ownerPublicKey = ownerKeypair.publicKey;
      console.log("Loaded agreement owner keypair from:", OWNER_KEYPAIR_PATH);
    } catch (error) {
      console.log("Generating new agreement owner keypair...");
      ownerKeypair = Keypair.generate();
      ownerPublicKey = ownerKeypair.publicKey;
      fs.writeFileSync(
        OWNER_KEYPAIR_PATH,
        JSON.stringify(Array.from(ownerKeypair.secretKey))
      );
      console.log("Saved agreement owner keypair to:", OWNER_KEYPAIR_PATH);
    }
  }

  console.log("Agreement owner:", ownerPublicKey.toString());

  // Check limitations when using address-only mode
  if (!ownerKeypair && OWNER_ADDRESS) {
    console.log("⚠️  Owner address-only mode:");
    console.log("   - Agreement creation: ✅ Supported");
    console.log("   - Post-creation operations: ❌ Not supported (require owner signature)");
    console.log("   - Prefunding: ❌ Not supported (requires owner to sign transfers)");
    console.log("   - Large agreements: ❌ Not supported (require progressive creation)");
  }

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
  // Use more conservative thresholds to avoid transaction size limits
  const isLargeAgreement = processedChains.length > 1 || totalAccounts > 5;

  // Restrict large agreements when using address-only mode
  if (!ownerKeypair && OWNER_ADDRESS && isLargeAgreement) {
    console.error("❌ Error: Large agreements require owner keypair for progressive creation");
    console.error("   This agreement has", processedChains.length, "chains and", totalAccounts, "accounts");
    console.error("   Please provide OWNER_KEYPAIR_PATH or reduce the agreement size");
    return;
  }

  if (isLargeAgreement) {
    console.log("📈 Large agreement detected - using progressive creation strategy");
    console.log(`   ${processedChains.length} chains, ${totalAccounts} accounts`);
  }

  // For owner address-only mode, create complete agreement upfront (no progressive approach)
  // For owner keypair mode, use progressive approach for large agreements
  const useProgressiveCreation = isLargeAgreement && ownerKeypair;
  const initialChainsCount = useProgressiveCreation ? Math.min(3, processedChains.length) : processedChains.length;
  const initialParams = useProgressiveCreation ? {
    ...params,
    chains: params.chains.slice(0, initialChainsCount).map(chain => ({
      ...chain,
      accounts: [] // Start with no accounts for progressive approach
    }))
  } : params; // Use complete params for non-progressive approach

  if (SHOULD_ADOPT) {
    console.log(useProgressiveCreation ? "📝 Creating agreement (without accounts first) then adopting..." : "📝 Creating complete agreement then adopting...");

    try {
      const seedPrefix = process.env.ADOPTION_SEED_PREFIX || "adoption_v2";
      const [adoptionPdaV2] = PublicKey.findProgramAddressSync(
        [Buffer.from(seedPrefix), provider.wallet.publicKey.toBuffer(), agreementKeypair.publicKey.toBuffer()],
        program.programId
      );
      const [adoptionPdaV1] = PublicKey.findProgramAddressSync(
        [Buffer.from("adoption"), provider.wallet.publicKey.toBuffer()],
        program.programId
      );
      const [adoptionHead] = PublicKey.findProgramAddressSync(
        [Buffer.from("adoption_head"), provider.wallet.publicKey.toBuffer()],
        program.programId
      );
      console.log("Adoption PDA v2:", adoptionPdaV2.toString());
      console.log("Adoption PDA v1:", adoptionPdaV1.toString());
      console.log("Adoption Head:", adoptionHead.toString());

      // Create agreement first
      const createTx = await program.methods
        .createAgreement(initialParams, ownerPublicKey)
        .accountsPartial({
          registry: registryPda,
          agreement: agreementKeypair.publicKey,
          owner: ownerPublicKey,
          payer: provider.wallet.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([agreementKeypair])
        .rpc();

      console.log("✅ Agreement created!", createTx);

      // Adopt the agreement
      const adoptTx = await program.methods
        .adoptSafeHarbor()
        .accountsPartial({
          registry: registryPda,
          adopter: provider.wallet.publicKey,
          agreement: agreementKeypair.publicKey,
          adoption: adoptionPdaV2,
          adoptionHead: adoptionHead,
          systemProgram: SystemProgram.programId,
        })
        .rpc();

      console.log("✅ Agreement adopted!", adoptTx);

      // Smart prefunding based on agreement size
      const estimatedRentSol = Math.max(0.1, Math.ceil(totalAccounts / 20));
      const prefundSol = Number(process.env.PREFUND_AGREEMENT_SOL || estimatedRentSol.toString());

      if (prefundSol > 0) {
        try {
          console.log(`💸 Prefunding agreement account with ${prefundSol} SOL for rent...`);
          const transferIx = SystemProgram.transfer({
            fromPubkey: ownerPublicKey,
            toPubkey: agreementKeypair.publicKey,
            lamports: Math.floor(prefundSol * LAMPORTS_PER_SOL),
          });
          const tx = new Transaction().add(transferIx);
          const sig = await provider.sendAndConfirm(tx, ownerKeypair ? [ownerKeypair] : []);
          console.log("  ✅ Prefund tx:", sig);
        } catch (prefundErr) {
          console.log("  ⚠️  Prefund failed (continuing):", (prefundErr as Error).message);
          console.log("     Agreement may fail during account additions if insufficient rent");
        }
      }

      // Add remaining chains progressively (if using progressive creation)
      if (useProgressiveCreation && processedChains.length > initialChainsCount) {
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
                owner: ownerPublicKey,
              })
              .signers(ownerKeypair ? [ownerKeypair] : [])
              .rpc();

            console.log(`    ✅ Added ${batch.length} chains`);
          } catch (error) {
            console.error(`    ❌ Error adding chain batch:`, error);
            // Continue with account additions even if some chains failed
          }
        }
      }

      // Now add accounts in batches (only for progressive creation)
      if (useProgressiveCreation) {
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
                  owner: ownerPublicKey,
                })
                .signers(ownerKeypair ? [ownerKeypair] : [])
                .rpc();

              console.log(`    ✅ Batch ${i / BATCH_SIZE + 1} added:`, addTx);
            } catch (error) {
              console.error(`    ❌ Error adding batch ${i / BATCH_SIZE + 1}:`, error);
              throw error; // Rethrow to be caught by outer try-catch
            }
          }
        }
      } // End useProgressiveCreation block

    } catch (error) {
      console.error("❌ Error creating and adopting agreement:", error);
      return;
    }
  } else {
    console.log(useProgressiveCreation ? "📝 Creating agreement (without accounts first)..." : "📝 Creating complete agreement...");

    try {
      const createTx = await program.methods
        .createAgreement(initialParams, ownerPublicKey)
        .accountsPartial({
          registry: registryPda,
          agreement: agreementKeypair.publicKey,
          owner: ownerPublicKey,
          payer: provider.wallet.publicKey,
          systemProgram: SystemProgram.programId,
        })
        .signers([agreementKeypair])
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
            fromPubkey: ownerPublicKey,
            toPubkey: agreementKeypair.publicKey,
            lamports: Math.floor(prefundSol * LAMPORTS_PER_SOL),
          });
          const tx = new Transaction().add(transferIx);
          const sig = await provider.sendAndConfirm(tx, ownerKeypair ? [ownerKeypair] : []);
          console.log("  ✅ Prefund tx:", sig);
        } catch (prefundErr) {
          console.log("  ⚠️  Prefund failed (continuing):", (prefundErr as Error).message);
          console.log("     Agreement may fail during account additions if insufficient rent");
        }
      }

      // Add remaining chains progressively (if using progressive creation)
      if (useProgressiveCreation && processedChains.length > initialChainsCount) {
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
                owner: ownerPublicKey,
              })
              .signers(ownerKeypair ? [ownerKeypair] : [])
              .rpc();

            console.log(`    ✅ Added ${batch.length} chains`);
          } catch (error) {
            console.error(`    ❌ Error adding chain batch:`, error);
            // Continue with account additions even if some chains failed
          }
        }
      }

      // Now add accounts in batches (only for progressive creation)
      if (useProgressiveCreation) {
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
                  owner: ownerPublicKey,
                })
                .signers(ownerKeypair ? [ownerKeypair] : [])
                .rpc();

              console.log(`    ✅ Batch ${i / BATCH_SIZE + 1} added:`, addTx);
            } catch (error) {
              console.error(`    ❌ Error adding batch ${i / BATCH_SIZE + 1}:`, error);
              throw error; // Rethrow to be caught by outer try-catch
            }
          }
        }
      } // End useProgressiveCreation block

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
    owner: ownerPublicKey.toString(),
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
  console.log("Owner:", ownerPublicKey.toString());
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
