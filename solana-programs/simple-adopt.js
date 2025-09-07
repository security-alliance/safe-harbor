const anchor = require('@coral-xyz/anchor');
const { PublicKey, Keypair, SystemProgram } = require('@solana/web3.js');
const fs = require('fs');

// Load deployment info
const deploymentInfo = JSON.parse(fs.readFileSync('./deployment-info.json', 'utf8'));

async function main() {
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  // Load the program
  const idl = JSON.parse(fs.readFileSync('./target/idl/safe_harbor.json', 'utf8'));
  const program = new anchor.Program(idl, deploymentInfo.programId, provider);

  console.log('🤝 Creating and Adopting Safe Harbor Agreement');
  console.log('Program ID:', deploymentInfo.programId);
  console.log('Registry PDA:', deploymentInfo.registryPda);

  // Create a new agreement keypair
  const agreementKeypair = Keypair.generate();
  console.log('Agreement Address:', agreementKeypair.publicKey.toString());

  // Sample agreement details
  const agreementDetails = {
    protocolName: "DemoProtocol",
    contact: [{
      name: "Security Team",
      contact: "security@demoprotocol.com"
    }],
    chains: [{
      id: "eip155:1", // Ethereum mainnet
      assetRecoveryAddress: "0x742d35Cc6634C0532925a3b8D400e4C0532925a3b8D400e4C",
      accounts: [{
        accountAddress: "0x1234567890123456789012345678901234567890",
        childContractScope: 0
      }]
    }],
    bountyTerms: {
      bountyPercentage: 10, // 10%
      bountyCapUSD: 100000, // $100k
      retainable: true,
      identity: 1, // KYC required
      diligenceRequirements: "Standard security audit required",
      aggregateBountyCapUSD: 500000 // $500k total
    },
    agreementURI: "https://example.com/agreement-details"
  };

  try {
    console.log('📝 Creating agreement...');
    
    // Create the agreement
    const createTx = await program.methods
      .createAgreement(agreementDetails)
      .accounts({
        agreement: agreementKeypair.publicKey,
        owner: provider.wallet.publicKey,
        payer: provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([agreementKeypair])
      .rpc();

    console.log('✅ Agreement created!');
    console.log('Transaction signature:', createTx);
    console.log('Agreement address:', agreementKeypair.publicKey.toString());

    console.log('🤝 Adopting safe harbor...');

    // Adopt the agreement
    const adoptTx = await program.methods
      .adoptSafeHarbor()
      .accounts({
        adopter: provider.wallet.publicKey,
        agreement: agreementKeypair.publicKey,
      })
      .rpc();

    console.log('✅ Safe harbor adopted!');
    console.log('Transaction signature:', adoptTx);

    // Query the adoption
    console.log('📊 Querying adoption status...');
    const agreementAccount = await program.account.agreement.fetch(agreementKeypair.publicKey);
    
    console.log('\n🎉 Success! Agreement Details:');
    console.log('=====================================');
    console.log('Protocol Name:', agreementAccount.protocolName);
    console.log('Owner:', agreementAccount.owner.toString());
    console.log('Created At:', new Date(agreementAccount.createdAt.toNumber() * 1000).toISOString());
    console.log('Adopters:', agreementAccount.adopters.length);
    console.log('Agreement URI:', agreementAccount.agreementUri);

    // Save agreement info
    const agreementInfo = {
      agreementAddress: agreementKeypair.publicKey.toString(),
      protocolName: agreementAccount.protocolName,
      owner: agreementAccount.owner.toString(),
      createdAt: agreementAccount.createdAt.toNumber(),
      adopters: agreementAccount.adopters.length,
      createTx,
      adoptTx
    };

    fs.writeFileSync('./agreement-info.json', JSON.stringify(agreementInfo, null, 2));
    console.log('📄 Agreement info saved to agreement-info.json');

  } catch (error) {
    console.error('❌ Error:', error);
    if (error.logs) {
      console.error('Program logs:', error.logs);
    }
  }
}

main().catch(console.error);
