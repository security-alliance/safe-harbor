use anchor_lang::prelude::*;

use crate::{
    AdoptSafeHarbor,
    AgreementOwnerOnly,
    AgreementOwnerWithRegistry,
    CreateAgreement,
    CreateAndAdoptAgreement,
    GetAgreement,
    InitializeRegistry,
    ReadOnlyAgreement,
    ReadOnlyRegistry,
    VersionContext,
    OwnerOnly,
};
use crate::errors::ErrorCode;
use crate::events::*;
use crate::helpers::{
    assert_agreement_owner,
    find_account_index,
    find_chain_index,
    resize_if_needed,
    validate_no_duplicate_chain_ids,
    VERSION,
};
use crate::state::{Agreement, Registry};
use crate::types::{AccountInScope, AgreementInitParams, BountyTerms, Chain, Contact};

pub fn initialize_registry(ctx: Context<InitializeRegistry>, owner: Pubkey) -> Result<()> {
    let reg = &mut ctx.accounts.registry;
    reg.owner = owner;
    reg.fallback_registry = None;
    reg.valid_chains = Vec::new();
    reg.agreements = crate::state::AccountMap { items: Vec::new() };

    let required_space = reg.calculate_required_space();
    resize_if_needed(&ctx.accounts.registry.to_account_info(), required_space)?;

    emit!(RegistryInitialized { owner });
    Ok(())
}

pub fn version() -> Result<String> {
    Ok(VERSION.to_string())
}

pub fn set_valid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
    let reg = &mut ctx.accounts.registry;
    require_keys_eq!(ctx.accounts.signer.key(), reg.owner, ErrorCode::Unauthorized);

    for chain in &chains {
        require!(!chain.is_empty(), ErrorCode::InvalidChainId);
        require!(chain.contains(':'), ErrorCode::InvalidChainId);
    }

    for c in chains.into_iter() {
        if !reg.valid_chains.contains(&c) {
            reg.valid_chains.push(c.clone());
            emit!(ChainValiditySet { caip2_chain_id: c.clone(), valid: true });
        }
    }

    let required_space = reg.calculate_required_space();
    resize_if_needed(&ctx.accounts.registry.to_account_info(), required_space)?;
    Ok(())
}

pub fn set_invalid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
    let reg = &mut ctx.accounts.registry;
    require_keys_eq!(ctx.accounts.signer.key(), reg.owner, ErrorCode::Unauthorized);

    for c in chains.into_iter() {
        if let Some(i) = reg.valid_chains.iter().position(|x| x == &c) {
            reg.valid_chains.swap_remove(i);
            emit!(ChainValiditySet { caip2_chain_id: c.clone(), valid: false });
        }
    }
    Ok(())
}

pub fn set_fallback_registry(ctx: Context<OwnerOnly>, fallback: Option<Pubkey>) -> Result<()> {
    let reg = &mut ctx.accounts.registry;
    require_keys_eq!(ctx.accounts.signer.key(), reg.owner, ErrorCode::Unauthorized);
    reg.fallback_registry = fallback;
    Ok(())
}

pub fn adopt_safe_harbor(ctx: Context<AdoptSafeHarbor>) -> Result<()> {
    let reg = &mut ctx.accounts.registry;
    let adopter = ctx.accounts.adopter.key();
    let old_agreement = reg.agreements.get(adopter);
    reg.agreements.insert(adopter, ctx.accounts.agreement.key());

    let required_space = reg.calculate_required_space();
    resize_if_needed(&ctx.accounts.registry.to_account_info(), required_space)?;

    emit!(SafeHarborAdoption {
        entity: adopter,
        old_details: old_agreement.unwrap_or_default(),
        new_details: ctx.accounts.agreement.key(),
    });
    Ok(())
}

pub fn get_agreement(ctx: Context<GetAgreement>, adopter: Pubkey) -> Result<Pubkey> {
    let reg = &ctx.accounts.registry;
    if let Some(agreement) = reg.agreements.get(adopter) {
        return Ok(agreement);
    }
    err!(ErrorCode::NoAgreement)
}

pub fn is_chain_valid(ctx: Context<ReadOnlyRegistry>, caip2_chain_id: String) -> Result<bool> {
    let reg = &ctx.accounts.registry;
    Ok(reg.valid_chains.contains(&caip2_chain_id))
}

pub fn get_valid_chains(ctx: Context<ReadOnlyRegistry>) -> Result<Vec<String>> {
    let reg = &ctx.accounts.registry;
    Ok(reg.valid_chains.clone())
}

pub fn create_agreement(
    ctx: Context<CreateAgreement>,
    params: AgreementInitParams,
    owner: Pubkey,
) -> Result<()> {
    let agreement = &mut ctx.accounts.agreement;
    let registry = &ctx.accounts.registry;

    for ch in params.chains.iter() {
        require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
    }
    require!(
        !(params.bounty_terms.aggregate_bounty_cap_usd > 0 && params.bounty_terms.retainable),
        ErrorCode::CannotSetBothAggregateBountyCapUSDAndRetainable
    );

    validate_no_duplicate_chain_ids(&params.chains)?;

    agreement.owner = owner;
    agreement.protocol_name = params.protocol_name;
    agreement.contact_details = params.contact_details;
    agreement.chains = params.chains;
    agreement.bounty_terms = params.bounty_terms;
    agreement.agreement_uri = params.agreement_uri;

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn set_protocol_name(ctx: Context<AgreementOwnerOnly>, protocol_name: String) -> Result<()> {
    require!(!protocol_name.is_empty(), ErrorCode::InvalidInput);
    require!(protocol_name.len() <= 128, ErrorCode::InvalidInput);
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    agreement.protocol_name = protocol_name;
    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn set_contact_details(ctx: Context<AgreementOwnerOnly>, contacts: Vec<Contact>) -> Result<()> {
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    agreement.contact_details = contacts;

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn add_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
    let registry = &ctx.accounts.registry;
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;

    for ch in chains.iter() {
        require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
    }

    for ch in chains.into_iter() {
        agreement.chains.push(ch);
    }

    validate_no_duplicate_chain_ids(&agreement.chains)?;

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn set_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
    let registry = &ctx.accounts.registry;
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    for ch in chains.iter() {
        require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
    }
    for new_ch in chains.into_iter() {
        let idx = find_chain_index(&agreement.chains, &new_ch.caip2_chain_id)?;
        agreement.chains[idx] = new_ch;
    }
    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn remove_chains(ctx: Context<AgreementOwnerOnly>, ids: Vec<String>) -> Result<()> {
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    for id in ids.into_iter() {
        let idx = find_chain_index(&agreement.chains, &id)?;
        agreement.chains.swap_remove(idx);
    }
    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn add_accounts(
    ctx: Context<AgreementOwnerOnly>,
    caip2_chain_id: String,
    accounts: Vec<AccountInScope>,
) -> Result<()> {
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    let idx = find_chain_index(&agreement.chains, &caip2_chain_id)?;

    for acc in accounts.into_iter() {
        agreement.chains[idx].accounts.push(acc);
    }

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn remove_accounts(
    ctx: Context<AgreementOwnerOnly>,
    caip2_chain_id: String,
    account_addresses: Vec<String>,
) -> Result<()> {
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    let idx = find_chain_index(&agreement.chains, &caip2_chain_id)?;
    for addr in account_addresses.into_iter() {
        let acc_idx = find_account_index(&agreement.chains[idx].accounts, &addr)?;
        agreement.chains[idx].accounts.swap_remove(acc_idx);
    }
    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn set_bounty_terms(ctx: Context<AgreementOwnerOnly>, terms: BountyTerms) -> Result<()> {
    require!(
        !(terms.aggregate_bounty_cap_usd > 0 && terms.retainable),
        ErrorCode::CannotSetBothAggregateBountyCapUSDAndRetainable
    );
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    agreement.bounty_terms = terms;

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn set_agreement_uri(ctx: Context<AgreementOwnerOnly>, agreement_uri: String) -> Result<()> {
    require!(!agreement_uri.is_empty(), ErrorCode::InvalidInput);
    assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
    let agreement = &mut ctx.accounts.agreement;
    agreement.agreement_uri = agreement_uri;

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    Ok(())
}

pub fn create_and_adopt_agreement(
    ctx: Context<CreateAndAdoptAgreement>,
    params: AgreementInitParams,
    owner: Pubkey,
) -> Result<()> {
    let registry = &mut ctx.accounts.registry;
    let agreement = &mut ctx.accounts.agreement;
    let adopter = ctx.accounts.adopter.key();

    for ch in params.chains.iter() {
        require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
    }
    require!(
        !(params.bounty_terms.aggregate_bounty_cap_usd > 0 && params.bounty_terms.retainable),
        ErrorCode::CannotSetBothAggregateBountyCapUSDAndRetainable
    );
    validate_no_duplicate_chain_ids(&params.chains)?;

    agreement.owner = owner;
    agreement.protocol_name = params.protocol_name;
    agreement.contact_details = params.contact_details;
    agreement.chains = params.chains;
    agreement.bounty_terms = params.bounty_terms;
    agreement.agreement_uri = params.agreement_uri;

    let required_space = agreement.calculate_required_space();
    resize_if_needed(&ctx.accounts.agreement.to_account_info(), required_space)?;

    let old_agreement = registry.agreements.get(adopter);
    registry.agreements.insert(adopter, ctx.accounts.agreement.key());

    let registry_required_space = registry.calculate_required_space();
    resize_if_needed(&ctx.accounts.registry.to_account_info(), registry_required_space)?;

    emit!(AgreementUpdated { agreement: ctx.accounts.agreement.key() });
    emit!(SafeHarborAdoption {
        entity: adopter,
        old_details: old_agreement.unwrap_or_default(),
        new_details: ctx.accounts.agreement.key(),
    });
    Ok(())
}

pub fn get_agreement_details() -> Result<()> {
    Ok(())
}


