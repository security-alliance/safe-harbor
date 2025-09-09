use anchor_lang::prelude::*;

// Program ID: ensure Anchor.toml matches this address for localnet
declare_id!("AE3K1g3QPY45R9u2aPyk5r1pVXHPUEF6UNAP76QHJi4L");

pub mod types;
pub mod state;
pub mod errors;
pub mod events;
pub mod contexts;
pub mod helpers;
mod instructions;

#[program]
pub mod safe_harbor {
    use super::*;
    use crate::contexts::*;
    use crate::types::{AgreementInitParams, Contact, Chain, AccountInScope, BountyTerms};

    pub fn initialize_registry(ctx: Context<InitializeRegistry>, owner: Pubkey) -> Result<()> {
        instructions::initialize_registry(ctx, owner)
    }

    pub fn version(_ctx: Context<VersionContext>) -> Result<String> {
        instructions::version()
    }

    pub fn set_valid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
        instructions::set_valid_chains(ctx, chains)
    }

    pub fn set_invalid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
        instructions::set_invalid_chains(ctx, chains)
    }

    pub fn set_fallback_registry(ctx: Context<OwnerOnly>, fallback: Option<Pubkey>) -> Result<()> {
        instructions::set_fallback_registry(ctx, fallback)
    }

    pub fn adopt_safe_harbor(ctx: Context<AdoptSafeHarbor>) -> Result<()> {
        instructions::adopt_safe_harbor(ctx)
    }

    pub fn get_agreement(ctx: Context<GetAgreement>, adopter: Pubkey) -> Result<Pubkey> {
        instructions::get_agreement(ctx, adopter)
    }

    pub fn is_chain_valid(ctx: Context<ReadOnlyRegistry>, caip2_chain_id: String) -> Result<bool> {
        instructions::is_chain_valid(ctx, caip2_chain_id)
    }

    pub fn get_valid_chains(ctx: Context<ReadOnlyRegistry>) -> Result<Vec<String>> {
        instructions::get_valid_chains(ctx)
    }

    pub fn create_agreement(
        ctx: Context<CreateAgreement>,
        params: AgreementInitParams,
        owner: Pubkey,
    ) -> Result<()> {
        instructions::create_agreement(ctx, params, owner)
    }

    pub fn set_protocol_name(ctx: Context<AgreementOwnerOnly>, protocol_name: String) -> Result<()> {
        instructions::set_protocol_name(ctx, protocol_name)
    }

    pub fn set_contact_details(ctx: Context<AgreementOwnerOnly>, contacts: Vec<Contact>) -> Result<()> {
        instructions::set_contact_details(ctx, contacts)
    }

    pub fn add_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
        instructions::add_chains(ctx, chains)
    }

    pub fn set_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
        instructions::set_chains(ctx, chains)
    }

    pub fn remove_chains(ctx: Context<AgreementOwnerOnly>, ids: Vec<String>) -> Result<()> {
        instructions::remove_chains(ctx, ids)
    }

    pub fn add_accounts(
        ctx: Context<AgreementOwnerOnly>,
        caip2_chain_id: String,
        accounts: Vec<AccountInScope>,
    ) -> Result<()> {
        instructions::add_accounts(ctx, caip2_chain_id, accounts)
    }

    pub fn remove_accounts(
        ctx: Context<AgreementOwnerOnly>,
        caip2_chain_id: String,
        account_addresses: Vec<String>,
    ) -> Result<()> {
        instructions::remove_accounts(ctx, caip2_chain_id, account_addresses)
    }

    pub fn set_bounty_terms(ctx: Context<AgreementOwnerOnly>, terms: BountyTerms) -> Result<()> {
        instructions::set_bounty_terms(ctx, terms)
    }

    pub fn set_agreement_uri(ctx: Context<AgreementOwnerOnly>, agreement_uri: String) -> Result<()> {
        instructions::set_agreement_uri(ctx, agreement_uri)
    }

    pub fn create_and_adopt_agreement(
        ctx: Context<CreateAndAdoptAgreement>,
        params: AgreementInitParams,
        owner: Pubkey,
    ) -> Result<()> {
        instructions::create_and_adopt_agreement(ctx, params, owner)
    }

    pub fn get_agreement_details(_ctx: Context<ReadOnlyAgreement>) -> Result<()> {
        instructions::get_agreement_details()
    }
}
