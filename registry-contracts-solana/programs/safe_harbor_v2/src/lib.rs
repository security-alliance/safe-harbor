pub mod error;
pub mod event;
pub mod instructions;
pub mod state;

use anchor_lang::prelude::*;

pub use instructions::*;
pub use state::*;

declare_id!("EkneQStBTPBmoCi6jmWFoF6Q5khNg2tj9kKPRuJzYvX9");

#[program]
pub mod safe_harbor_v2 {
    use super::*;

    pub fn adopt_safe_harbor(ctx: Context<AdoptSafeHarbor>, agreement: Pubkey) -> Result<()> {
        adopt_safe_harbor_handler(ctx, agreement)
    }

    pub fn create_agreement(
        ctx: Context<CreateAgreement>,
        protocol_name: String,
        contact_details: [Contact; 10],
        asset_recovery_address: Pubkey,
        bounty_terms: BountyTerms,
        agreement_uri: String,
        owner: Pubkey,
    ) -> Result<()> {
        create_agreement_handler(
            ctx,
            protocol_name,
            contact_details,
            asset_recovery_address,
            bounty_terms,
            agreement_uri,
            owner,
        )
    }

    pub fn close_agreement(ctx: Context<CloseAgreement>) -> Result<()> {
        close_agreement_handler(ctx)
    }

    pub fn set_protocol_name(ctx: Context<MutateAgreement>, name: String) -> Result<()> {
        set_protocol_name_handler(ctx, name)
    }

    pub fn set_contact_details(
        ctx: Context<MutateAgreement>,
        contact_details: [Contact; 10],
    ) -> Result<()> {
        set_contact_details_handler(ctx, contact_details)
    }

    pub fn set_asset_recovery_address(
        ctx: Context<MutateAgreement>,
        address: Pubkey,
    ) -> Result<()> {
        set_asset_recovery_address_handler(ctx, address)
    }

    pub fn set_agreement_uri(ctx: Context<MutateAgreement>, uri: String) -> Result<()> {
        set_agreement_uri_handler(ctx, uri)
    }

    pub fn add_account(
        ctx: Context<AddAccount>,
        account_address: Pubkey,
        child_contract_scope: ChildContractScope,
    ) -> Result<()> {
        add_account_handler(ctx, account_address, child_contract_scope)
    }

    pub fn remove_account(ctx: Context<RemoveAccount>) -> Result<()> {
        remove_account_handler(ctx)
    }

    pub fn set_bounty_terms(ctx: Context<MutateAgreement>, terms: BountyTerms) -> Result<()> {
        set_bounty_terms_handler(ctx, terms)
    }

    pub fn transfer_ownership(ctx: Context<MutateAgreement>, new_owner: Pubkey) -> Result<()> {
        transfer_ownership_handler(ctx, new_owner)
    }
}
