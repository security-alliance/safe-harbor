use anchor_lang::prelude::*;
use anchor_lang::InstructionData;
use anchor_lang::ToAccountMetas;
use solana_program_test::*;
use solana_sdk::{
    instruction::Instruction,
    pubkey::Pubkey,
    signature::{Keypair, Signer},
    transaction::Transaction,
};
use safe_harbor::*;

#[tokio::test]
async fn test_initialize_registry() {
    let program_id = safe_harbor::id();
    let mut program_test = ProgramTest::new("safe_harbor", program_id, processor!(safe_harbor::entry));
    
    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;
    
    let owner = Keypair::new();
    let (registry_pda, _bump) = Pubkey::find_program_address(&[b"registry"], &program_id);
    
    let accounts = safe_harbor::accounts::InitializeRegistry {
        registry: registry_pda,
        payer: payer.pubkey(),
        system_program: solana_program::system_program::id(),
    };
    
    let instruction = Instruction {
        program_id,
        accounts: accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::InitializeRegistry {
            owner: owner.pubkey(),
        }.data(),
    };
    
    let transaction = Transaction::new_signed_with_payer(
        &[instruction],
        Some(&payer.pubkey()),
        &[&payer],
        recent_blockhash,
    );
    
    banks_client.process_transaction(transaction).await.unwrap();
    
    // Verify registry was initialized
    let registry_account = banks_client.get_account(registry_pda).await.unwrap().unwrap();
    assert_eq!(registry_account.owner, program_id);
}

#[tokio::test]
async fn test_set_valid_chains() {
    let program_id = safe_harbor::id();
    let mut program_test = ProgramTest::new("safe_harbor", program_id, processor!(safe_harbor::entry));
    
    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;
    
    let owner = Keypair::new();
    let (registry_pda, _bump) = Pubkey::find_program_address(&[b"registry"], &program_id);
    
    // Initialize registry first
    let init_accounts = safe_harbor::accounts::InitializeRegistry {
        registry: registry_pda,
        payer: payer.pubkey(),
        system_program: solana_program::system_program::id(),
    };
    
    let init_instruction = Instruction {
        program_id,
        accounts: init_accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::InitializeRegistry {
            owner: owner.pubkey(),
        }.data(),
    };
    
    let init_transaction = Transaction::new_signed_with_payer(
        &[init_instruction],
        Some(&payer.pubkey()),
        &[&payer],
        recent_blockhash,
    );
    
    banks_client.process_transaction(init_transaction).await.unwrap();
    
    // Set valid chains
    let chains = vec!["eip155:1".to_string(), "eip155:137".to_string()];
    
    let accounts = safe_harbor::accounts::OwnerOnly {
        registry: registry_pda,
        signer: owner.pubkey(),
    };
    
    let instruction = Instruction {
        program_id,
        accounts: accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::SetValidChains { chains }.data(),
    };
    
    let transaction = Transaction::new_signed_with_payer(
        &[instruction],
        Some(&payer.pubkey()),
        &[&payer, &owner],
        recent_blockhash,
    );
    
    banks_client.process_transaction(transaction).await.unwrap();
}

#[tokio::test]
async fn test_create_agreement() {
    let program_id = safe_harbor::id();
    let mut program_test = ProgramTest::new("safe_harbor", program_id, processor!(safe_harbor::entry));
    
    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;
    
    let owner = Keypair::new();
    let agreement_keypair = Keypair::new();
    let (registry_pda, _bump) = Pubkey::find_program_address(&[b"registry"], &program_id);
    
    // Initialize registry first
    let init_accounts = safe_harbor::accounts::InitializeRegistry {
        registry: registry_pda,
        payer: payer.pubkey(),
        system_program: solana_program::system_program::id(),
    };
    
    let init_instruction = Instruction {
        program_id,
        accounts: init_accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::InitializeRegistry {
            owner: owner.pubkey(),
        }.data(),
    };
    
    let init_transaction = Transaction::new_signed_with_payer(
        &[init_instruction],
        Some(&payer.pubkey()),
        &[&payer],
        recent_blockhash,
    );
    
    banks_client.process_transaction(init_transaction).await.unwrap();
    
    // Set valid chains
    let chains = vec!["eip155:1".to_string()];
    
    let set_chains_accounts = safe_harbor::accounts::OwnerOnly {
        registry: registry_pda,
        signer: owner.pubkey(),
    };
    
    let set_chains_instruction = Instruction {
        program_id,
        accounts: set_chains_accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::SetValidChains { chains }.data(),
    };
    
    let set_chains_transaction = Transaction::new_signed_with_payer(
        &[set_chains_instruction],
        Some(&payer.pubkey()),
        &[&payer, &owner],
        recent_blockhash,
    );
    
    banks_client.process_transaction(set_chains_transaction).await.unwrap();
    
    // Create agreement
    let params = AgreementInitParams {
        protocol_name: "Test Protocol".to_string(),
        contact_details: vec![Contact {
            name: "Test Contact".to_string(),
            contact: "test@example.com".to_string(),
        }],
        chains: vec![Chain {
            asset_recovery_address: "0x1234567890123456789012345678901234567890".to_string(),
            accounts: vec![AccountInScope {
                account_address: "0x1234567890123456789012345678901234567890".to_string(),
                child_contract_scope: ChildContractScope::None,
            }],
            caip2_chain_id: "eip155:1".to_string(),
        }],
        bounty_terms: BountyTerms {
            bounty_percentage: 10,
            bounty_cap_usd: 100000,
            retainable: true,
            identity: IdentityRequirements::Anonymous,
            diligence_requirements: "Standard diligence".to_string(),
            aggregate_bounty_cap_usd: 0,
        },
        agreement_uri: "ipfs://QmTest".to_string(),
    };
    
    let create_accounts = safe_harbor::accounts::CreateAgreement {
        registry: registry_pda,
        agreement: agreement_keypair.pubkey(),
        owner: owner.pubkey(),
        payer: payer.pubkey(),
        system_program: solana_program::system_program::id(),
    };
    
    let create_instruction = Instruction {
        program_id,
        accounts: create_accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::CreateAgreement { params }.data(),
    };
    
    let create_transaction = Transaction::new_signed_with_payer(
        &[create_instruction],
        Some(&payer.pubkey()),
        &[&payer, &owner, &agreement_keypair],
        recent_blockhash,
    );
    
    banks_client.process_transaction(create_transaction).await.unwrap();
    
    // Verify agreement was created
    let agreement_account = banks_client.get_account(agreement_keypair.pubkey()).await.unwrap().unwrap();
    assert_eq!(agreement_account.owner, program_id);
}

#[tokio::test]
async fn test_adopt_safe_harbor() {
    let program_id = safe_harbor::id();
    let mut program_test = ProgramTest::new("safe_harbor", program_id, processor!(safe_harbor::entry));
    
    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;
    
    let owner = Keypair::new();
    let adopter = Keypair::new();
    let agreement_keypair = Keypair::new();
    let (registry_pda, _bump) = Pubkey::find_program_address(&[b"registry"], &program_id);
    
    // Initialize registry
    let init_accounts = safe_harbor::accounts::InitializeRegistry {
        registry: registry_pda,
        payer: payer.pubkey(),
        system_program: solana_program::system_program::id(),
    };
    
    let init_instruction = Instruction {
        program_id,
        accounts: init_accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::InitializeRegistry {
            owner: owner.pubkey(),
        }.data(),
    };
    
    let init_transaction = Transaction::new_signed_with_payer(
        &[init_instruction],
        Some(&payer.pubkey()),
        &[&payer],
        recent_blockhash,
    );
    
    banks_client.process_transaction(init_transaction).await.unwrap();
    
    // Adopt safe harbor
    let adopt_accounts = safe_harbor::accounts::AdoptSafeHarbor {
        registry: registry_pda,
        adopter: adopter.pubkey(),
        agreement: agreement_keypair.pubkey(),
    };
    
    let adopt_instruction = Instruction {
        program_id,
        accounts: adopt_accounts.to_account_metas(Some(true)),
        data: safe_harbor::instruction::AdoptSafeHarbor {}.data(),
    };
    
    let adopt_transaction = Transaction::new_signed_with_payer(
        &[adopt_instruction],
        Some(&payer.pubkey()),
        &[&payer, &adopter],
        recent_blockhash,
    );
    
    banks_client.process_transaction(adopt_transaction).await.unwrap();
}
