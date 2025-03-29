use anchor_lang::prelude::*;

use crate::{
    error::ErrorCode,
    event::{AddAccountEvent, RemoveAccountEvent, SafeHarborUpdateEvent},
    state::agreement_state::{AccountRecord, Agreement, BountyTerms, ChildContractScope, Contact},
};

pub fn create_agreement_handler(
    ctx: Context<CreateAgreement>,
    protocol_name: String,
    contact_details: [Contact; 10],
    asset_recovery_address: Pubkey,
    bounty_terms: BountyTerms,
    agreement_uri: String,
    owner: Pubkey,
) -> Result<()> {
    let agreement = &mut ctx.accounts.agreement;

    agreement.owner = owner;
    agreement.protocol_name = protocol_name;
    agreement.contact_details = contact_details;
    agreement.asset_recovery_address = asset_recovery_address;
    agreement.bounty_terms = bounty_terms;
    agreement.agreement_uri = agreement_uri;
    agreement.bump = ctx.bumps.agreement;

    emit!(SafeHarborUpdateEvent {
        agreement: agreement.key(),
    });

    Ok(())
}

pub fn close_agreement_handler(ctx: Context<CloseAgreement>) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

pub fn set_protocol_name_handler(ctx: Context<MutateAgreement>, name: String) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );
    ctx.accounts.agreement.protocol_name = name;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

pub fn set_contact_details_handler(
    ctx: Context<MutateAgreement>,
    contact_details: [Contact; 10],
) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );
    ctx.accounts.agreement.contact_details = contact_details;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

pub fn set_asset_recovery_address_handler(
    ctx: Context<MutateAgreement>,
    asset_recovery_address: Pubkey,
) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );
    ctx.accounts.agreement.asset_recovery_address = asset_recovery_address;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

pub fn set_agreement_uri_handler(ctx: Context<MutateAgreement>, uri: String) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );
    ctx.accounts.agreement.agreement_uri = uri;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

pub fn add_account_handler(
    ctx: Context<AddAccount>,
    account_address: Pubkey,
    child_contract_scope: ChildContractScope,
) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );

    let account_record = &mut ctx.accounts.account_record;
    account_record.account_address = account_address;
    account_record.child_contract_scope = child_contract_scope;
    account_record.bump = ctx.bumps.account_record;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    emit!(AddAccountEvent {
        account_address: account_address,
    });

    Ok(())
}

pub fn remove_account_handler(ctx: Context<RemoveAccount>) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    emit!(RemoveAccountEvent {
        account_address: ctx.accounts.account_record.account_address,
    });

    Ok(()) // Anchor will close the account
}

pub fn set_bounty_terms_handler(ctx: Context<MutateAgreement>, terms: BountyTerms) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );
    ctx.accounts.agreement.bounty_terms = terms;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

pub fn transfer_ownership_handler(ctx: Context<MutateAgreement>, new_owner: Pubkey) -> Result<()> {
    require_keys_eq!(
        ctx.accounts.authority.key(),
        ctx.accounts.agreement.owner,
        ErrorCode::Unauthorized
    );
    ctx.accounts.agreement.owner = new_owner;

    emit!(SafeHarborUpdateEvent {
        agreement: ctx.accounts.agreement.key(),
    });

    Ok(())
}

#[derive(Accounts)]
#[instruction(protocol_name: String)]
pub struct CreateAgreement<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + Agreement::INIT_SPACE,
        seeds = [b"agreement", authority.key().as_ref()],
        bump
    )]
    pub agreement: Account<'info, Agreement>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CloseAgreement<'info> {
    #[account(mut, close = authority)]
    pub agreement: Account<'info, Agreement>,
    #[account(mut)]
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct MutateAgreement<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,

    pub authority: Signer<'info>,
}

#[derive(Accounts)]
#[instruction(account_address: Pubkey)]
pub struct AddAccount<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,

    #[account(
        init,
        payer = authority,
        space = 8 + AccountRecord::INIT_SPACE,
        seeds = [b"account", agreement.key().as_ref(), account_address.as_ref()],
        bump
    )]
    pub account_record: Account<'info, AccountRecord>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RemoveAccount<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,

    #[account(mut, close = authority)]
    pub account_record: Account<'info, AccountRecord>,

    #[account(mut)]
    pub authority: Signer<'info>,
}
