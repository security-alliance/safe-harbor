use anchor_lang::prelude::*;

// Program ID: ensure Anchor.toml matches this address for localnet
declare_id!("64Gpb6dztgGMcWPkQrDV4VjFHSfXTPoDtrhEu8ykXFKU");

pub mod types;
pub mod state;
pub mod errors;
pub mod events;
pub mod helpers;
pub mod instructions;

// Re-export commonly used types at crate root for compatibility with existing tests/clients
pub use crate::types::{
    Contact,
    AccountInScope,
    Chain,
    ChildContractScope,
    IdentityRequirements,
    BountyTerms,
    AgreementInitParams,
};
pub use crate::state::{Registry, Agreement, AdoptionEntry, AgreementChainIndex, AgreementAccountIndex};

#[program]
pub mod safe_harbor {
    use anchor_lang::prelude::*;
    use super::*;
    use crate::types::{AgreementInitParams, Contact, Chain, AccountInScope, BountyTerms};

    pub fn initialize_registry(ctx: Context<InitializeRegistry>, owner: Pubkey) -> Result<()> {
        crate::instructions::initialize_registry(ctx, owner)
    }

    pub fn version(_ctx: Context<VersionContext>) -> Result<String> {
        crate::instructions::version()
    }

    pub fn set_valid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
        crate::instructions::set_valid_chains(ctx, chains)
    }

    pub fn set_invalid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
        crate::instructions::set_invalid_chains(ctx, chains)
    }

    pub fn set_fallback_registry(ctx: Context<OwnerOnly>, fallback: Option<Pubkey>) -> Result<()> {
        crate::instructions::set_fallback_registry(ctx, fallback)
    }

    pub fn adopt_safe_harbor(ctx: Context<AdoptSafeHarbor>) -> Result<()> {
        crate::instructions::adopt_safe_harbor(ctx)
    }

    pub fn get_agreement(ctx: Context<GetAgreement>, adopter: Pubkey) -> Result<Pubkey> {
        crate::instructions::get_agreement(ctx, adopter)
    }

    pub fn is_chain_valid(ctx: Context<ReadOnlyRegistry>, caip2_chain_id: String) -> Result<bool> {
        crate::instructions::is_chain_valid(ctx, caip2_chain_id)
    }

    pub fn get_valid_chains(ctx: Context<ReadOnlyRegistry>) -> Result<Vec<String>> {
        crate::instructions::get_valid_chains(ctx)
    }

    pub fn create_agreement(
        ctx: Context<CreateAgreement>,
        params: AgreementInitParams,
        owner: Pubkey,
    ) -> Result<()> {
        crate::instructions::create_agreement(ctx, params, owner)
    }

    pub fn set_protocol_name(ctx: Context<AgreementOwnerOnly>, protocol_name: String) -> Result<()> {
        crate::instructions::set_protocol_name(ctx, protocol_name)
    }

    pub fn set_contact_details(ctx: Context<AgreementOwnerOnly>, contacts: Vec<Contact>) -> Result<()> {
        crate::instructions::set_contact_details(ctx, contacts)
    }

    pub fn add_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
        crate::instructions::add_chains(ctx, chains)
    }

    pub fn set_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
        crate::instructions::set_chains(ctx, chains)
    }

    pub fn remove_chains(ctx: Context<AgreementOwnerOnly>, ids: Vec<String>) -> Result<()> {
        crate::instructions::remove_chains(ctx, ids)
    }

    pub fn add_accounts(
        ctx: Context<AgreementOwnerOnly>,
        caip2_chain_id: String,
        accounts: Vec<AccountInScope>,
    ) -> Result<()> {
        crate::instructions::add_accounts(ctx, caip2_chain_id, accounts)
    }

    pub fn remove_accounts(
        ctx: Context<AgreementOwnerOnly>,
        caip2_chain_id: String,
        account_addresses: Vec<String>,
    ) -> Result<()> {
        crate::instructions::remove_accounts(ctx, caip2_chain_id, account_addresses)
    }

    pub fn set_bounty_terms(ctx: Context<AgreementOwnerOnly>, terms: BountyTerms) -> Result<()> {
        crate::instructions::set_bounty_terms(ctx, terms)
    }

    pub fn set_agreement_uri(ctx: Context<AgreementOwnerOnly>, agreement_uri: String) -> Result<()> {
        crate::instructions::set_agreement_uri(ctx, agreement_uri)
    }

    pub fn transfer_ownership(ctx: Context<AgreementOwnerSignerOnly>, new_owner: Pubkey) -> Result<()> {
        crate::instructions::transfer_ownership(ctx, new_owner)
    }

    pub fn create_and_adopt_agreement(
        ctx: Context<CreateAndAdoptAgreement>,
        params: AgreementInitParams,
        owner: Pubkey,
    ) -> Result<()> {
        crate::instructions::create_and_adopt_agreement(ctx, params, owner)
    }

    pub fn get_agreement_details(_ctx: Context<ReadOnlyAgreement>) -> Result<()> {
        crate::instructions::get_agreement_details()
    }

    // Optional PDA-based lookups
    pub fn get_agreement_by_pda(ctx: Context<GetAgreementByPda>) -> Result<Pubkey> {
        crate::instructions::get_agreement_by_pda(ctx)
    }
}

// -------------------- Contexts --------------------

#[derive(Accounts)]
pub struct InitializeRegistry<'info> {
    #[account(
        init,
        payer = payer,
        space = Registry::INITIAL_SPACE,
        seeds = [b"registry"],
        bump
    )]
    pub registry: Account<'info, Registry>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct OwnerOnly<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct AdoptSafeHarbor<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    #[account(mut)]
    pub adopter: Signer<'info>,
    #[account(
        init_if_needed,
        payer = adopter,
        space = AdoptionEntry::SPACE,
        seeds = [b"adoption_v2", adopter.key().as_ref(), agreement.key().as_ref()],
        bump,
        constraint = adoption.key() == Pubkey::find_program_address(&[b"adoption_v2", adopter.key().as_ref(), agreement.key().as_ref()], &crate::id()).0
    )]
    pub adoption: Account<'info, AdoptionEntry>,
    /// CHECK: agreement PDA or normal account; stored as pubkey only
    pub agreement: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CreateAgreement<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    #[account(
        init,
        payer = payer,
        space = Agreement::INITIAL_SPACE,
    )]
    pub agreement: Account<'info, Agreement>,
    /// CHECK: Owner can be any valid pubkey, doesn't need to sign for creation
    pub owner: UncheckedAccount<'info>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CreateAndAdoptAgreement<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    #[account(
        init,
        payer = adopter,
        space = Agreement::INITIAL_SPACE,
    )]
    pub agreement: Account<'info, Agreement>,
    /// CHECK: Owner can be any valid pubkey, doesn't need to sign for creation
    pub owner: UncheckedAccount<'info>,
    #[account(mut)]
    pub adopter: Signer<'info>,
    #[account(
        init_if_needed,
        payer = adopter,
        space = AdoptionEntry::SPACE,
        seeds = [b"adoption_v2", adopter.key().as_ref(), agreement.key().as_ref()],
        bump
    )]
    pub adoption: Account<'info, AdoptionEntry>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AgreementOwnerOnly<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,
    // Owner must sign; validated against the agreement's owner field
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct AgreementOwnerWithRegistry<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,
    // Owner must sign; validated against the agreement's owner field
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct AgreementOwnerSignerOnly<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct VersionContext<'info> {
    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct GetAgreement<'info> {
    #[account(seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
}

#[derive(Accounts)]
pub struct ReadOnlyRegistry<'info> {
    #[account(seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
}

#[derive(Accounts)]
pub struct GetAgreementByPda<'info> {
    /// CHECK: adopter passed to seed derivation
    pub adopter: UncheckedAccount<'info>,
    /// CHECK: agreement passed to seed derivation
    pub agreement: UncheckedAccount<'info>,
    #[account(
        seeds=[b"adoption_v2", adopter.key().as_ref(), agreement.key().as_ref()],
        bump
    )]
    pub adoption: Account<'info, AdoptionEntry>,
}

#[derive(Accounts)]
pub struct ReadOnlyAgreement<'info> {
    pub agreement: Account<'info, Agreement>,
}
