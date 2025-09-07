import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const DEPLOYMENT_INFO_PATH = "./deployment-info.json";

async function main() {
  console.log("🔍 Reading and Decoding On-Chain Agreement Data");
  console.log("=" .repeat(60));

  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

  // Load deployment info
  const deploymentInfo = JSON.parse(fs.readFileSync(DEPLOYMENT_INFO_PATH, "utf8"));
  
  console.log("📋 Program ID:", deploymentInfo.programId);
  console.log("🏛️  Registry PDA:", deploymentInfo.registryPda);
  console.log("📄 Agreement Address:", deploymentInfo.testAgreement.address);
  console.log("👤 Adopter Address:", deploymentInfo.testAgreement.adopter);

  // Read Registry Data
  console.log("\n🏛️  REGISTRY DATA");
  console.log("-".repeat(40));
  
  try {
    const registryPda = new PublicKey(deploymentInfo.registryPda);
    const registryAccount = await program.account.registry.fetch(registryPda);
    
    console.log("👤 Owner:", registryAccount.owner.toString());
    console.log("🔄 Fallback Registry:", registryAccount.fallbackRegistry ? registryAccount.fallbackRegistry.toString() : "None");
    console.log("⛓️  Valid Chains:", registryAccount.validChains.length);
    
    console.log("\n📋 Supported Blockchain Networks:");
    registryAccount.validChains.forEach((chain, index) => {
      const chainName = getChainName(chain);
      console.log(`  ${index + 1}. ${chainName} (${chain})`);
    });
    
    console.log("\n🤝 Active Adoptions:", registryAccount.agreements.items.length);
    registryAccount.agreements.items.forEach((adoption, index) => {
      console.log(`  ${index + 1}. Entity: ${adoption.key.toString()}`);
      console.log(`     Agreement: ${adoption.value.toString()}`);
    });
    
  } catch (error) {
    console.error("❌ Error reading registry:", error);
    return;
  }

  // Read Agreement Data
  console.log("\n📄 AGREEMENT DATA");
  console.log("-".repeat(40));
  
  try {
    const agreementAddress = new PublicKey(deploymentInfo.testAgreement.address);
    const agreementAccount = await program.account.agreement.fetch(agreementAddress);
    
    console.log("📝 Protocol Name:", agreementAccount.protocolName);
    console.log("👤 Owner:", agreementAccount.owner.toString());
    console.log("🔗 Agreement URI:", agreementAccount.agreementUri);
    
    console.log("\n📞 CONTACT INFORMATION");
    console.log("-".repeat(25));
    agreementAccount.contactDetails.forEach((contact, index) => {
      console.log(`${index + 1}. ${contact.name}: ${contact.contact}`);
    });
    
    console.log("\n⛓️  BLOCKCHAIN COVERAGE");
    console.log("-".repeat(25));
    agreementAccount.chains.forEach((chain, chainIndex) => {
      const chainName = getChainName(chain.caip2ChainId);
      console.log(`\n🌐 ${chainName} (${chain.caip2ChainId})`);
      console.log(`   💰 Asset Recovery Address: ${chain.assetRecoveryAddress}`);
      console.log(`   📊 Accounts in Scope: ${chain.accounts.length}`);
      
      chain.accounts.forEach((account, accIndex) => {
        const scopeDescription = getChildContractScopeDescription(account.childContractScope);
        console.log(`     ${accIndex + 1}. ${account.accountAddress}`);
        console.log(`        🔍 Child Contract Scope: ${scopeDescription}`);
      });
    });
    
    console.log("\n💰 BOUNTY TERMS");
    console.log("-".repeat(15));
    console.log(`💵 Bounty Percentage: ${agreementAccount.bountyTerms.bountyPercentage}%`);
    console.log(`💸 Maximum Bounty Cap: $${agreementAccount.bountyTerms.bountyCapUsd.toLocaleString()} USD`);
    console.log(`🔄 Retainable: ${agreementAccount.bountyTerms.retainable ? "Yes" : "No"}`);
    console.log(`🆔 Identity Requirements: ${getIdentityRequirements(agreementAccount.bountyTerms.identity)}`);
    console.log(`📋 Diligence Requirements: ${agreementAccount.bountyTerms.diligenceRequirements}`);
    
    if (agreementAccount.bountyTerms.aggregateBountyCapUsd.gt(new anchor.BN(0))) {
      console.log(`🎯 Aggregate Bounty Cap: $${agreementAccount.bountyTerms.aggregateBountyCapUsd.toLocaleString()} USD`);
    } else {
      console.log(`🎯 Aggregate Bounty Cap: No limit (individual caps apply)`);
    }
    
    // Calculate total accounts across all chains
    const totalAccounts = agreementAccount.chains.reduce((sum, chain) => sum + chain.accounts.length, 0);
    
    console.log("\n📊 SUMMARY STATISTICS");
    console.log("-".repeat(20));
    console.log(`🌐 Total Blockchains: ${agreementAccount.chains.length}`);
    console.log(`📱 Total Accounts: ${totalAccounts}`);
    console.log(`📞 Contact Methods: ${agreementAccount.contactDetails.length}`);
    console.log(`💰 Max Individual Payout: $${agreementAccount.bountyTerms.bountyCapUsd.toLocaleString()}`);
    
    console.log("\n🔐 SECURITY SCOPE BREAKDOWN");
    console.log("-".repeat(30));
    const scopeStats = {
      none: 0,
      existingOnly: 0,
      all: 0,
      futureOnly: 0
    };
    
    agreementAccount.chains.forEach(chain => {
      chain.accounts.forEach(account => {
        if ('none' in account.childContractScope) scopeStats.none++;
        else if ('existingOnly' in account.childContractScope) scopeStats.existingOnly++;
        else if ('all' in account.childContractScope) scopeStats.all++;
        else if ('futureOnly' in account.childContractScope) scopeStats.futureOnly++;
      });
    });
    
    console.log(`🚫 No Child Contracts: ${scopeStats.none} accounts`);
    console.log(`📅 Existing Child Contracts Only: ${scopeStats.existingOnly} accounts`);
    console.log(`🌐 All Child Contracts: ${scopeStats.all} accounts`);
    console.log(`🔮 Future Child Contracts Only: ${scopeStats.futureOnly} accounts`);
    
  } catch (error) {
    console.error("❌ Error reading agreement:", error);
    return;
  }

  console.log("\n✅ On-chain data successfully decoded and displayed!");
  console.log("🔗 View on Solana Explorer:");
  console.log(`   Registry: https://explorer.solana.com/address/${deploymentInfo.registryPda}?cluster=devnet`);
  console.log(`   Agreement: https://explorer.solana.com/address/${deploymentInfo.testAgreement.address}?cluster=devnet`);
}

function getChainName(caip2Id: string): string {
  const chainMap: { [key: string]: string } = {
    "eip155:1": "Ethereum Mainnet",
    "eip155:137": "Polygon",
    "eip155:42161": "Arbitrum One",
    "eip155:10": "Optimism",
    "eip155:8453": "Base",
    "eip155:43114": "Avalanche C-Chain",
    "eip155:56": "BNB Smart Chain",
    "eip155:100": "Gnosis Chain"
  };
  
  return chainMap[caip2Id] || `Unknown Chain (${caip2Id})`;
}

function getChildContractScopeDescription(scope: any): string {
  if ('none' in scope) {
    return "No child contracts included";
  } else if ('existingOnly' in scope) {
    return "Only existing child contracts at time of agreement";
  } else if ('all' in scope) {
    return "All child contracts (existing and future)";
  } else if ('futureOnly' in scope) {
    return "Only future child contracts created after agreement";
  }
  return "Unknown scope";
}

function getIdentityRequirements(identity: any): string {
  if ('anonymous' in identity) {
    return "Anonymous (No KYC required)";
  } else if ('pseudonymous' in identity) {
    return "Pseudonymous (Pseudonym required)";
  } else if ('named' in identity) {
    return "Named (Legal name required)";
  }
  return "Unknown identity requirement";
}

main().catch((error) => {
  console.error("❌ Failed to read chain data:", error);
  process.exit(1);
});
