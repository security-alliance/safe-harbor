use anchor_lang::prelude::*;

// Program ID: ensure Anchor.toml matches this address for localnet
declare_id!("AE3K1g3QPY45R9u2aPyk5r1pVXHPUEF6UNAP76QHJi4L");

const VERSION: &str = "2.0.0";

#[allow(deprecated)]
#[program]
pub mod safe_harbor {
    use super::*;

    // Initialize the singleton registry with an owner
    pub fn initialize_registry(ctx: Context<InitializeRegistry>, owner: Pubkey) -> Result<()> {
        let reg = &mut ctx.accounts.registry;
        reg.owner = owner;
        reg.fallback_registry = None;
        reg.valid_chains = Vec::new();
        reg.agreements = AccountMap { items: Vec::new() };
        emit!(RegistryInitialized { owner });
        Ok(())
    }

    // Get the version of the program
    pub fn version(_ctx: Context<VersionContext>) -> Result<String> {
        Ok(VERSION.to_string())
    }

    // Owner-only: set a list of chains as valid (adds if missing)
    pub fn set_valid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
        let reg = &mut ctx.accounts.registry;
        require_keys_eq!(ctx.accounts.signer.key(), reg.owner, ErrorCode::Unauthorized);
        
        // Validate chain ID format (basic CAIP-2 validation)
        for chain in &chains {
            require!(!chain.is_empty(), ErrorCode::InvalidChainId);
            require!(chain.contains(':'), ErrorCode::InvalidChainId);
        }
        
        for c in chains.into_iter() {
            if !reg.valid_chains.contains(&c) {
                reg.valid_chains.push(c.clone());
                emit!(ChainValiditySet { 
                    caip2_chain_id: c.clone(), 
                    valid: true 
                });
            }
        }
        Ok(())
    }

    // Owner-only: mark a list of chains as invalid (removes if present)
    pub fn set_invalid_chains(ctx: Context<OwnerOnly>, chains: Vec<String>) -> Result<()> {
        let reg = &mut ctx.accounts.registry;
        require_keys_eq!(ctx.accounts.signer.key(), reg.owner, ErrorCode::Unauthorized);
        for c in chains.into_iter() {
            if let Some(i) = reg.valid_chains.iter().position(|x| x == &c) {
                reg.valid_chains.swap_remove(i);
                emit!(ChainValiditySet { 
                    caip2_chain_id: c.clone(), 
                    valid: false 
                });
            }
        }
        Ok(())
    }

    // Owner-only: set fallback registry address (optional)
    pub fn set_fallback_registry(ctx: Context<OwnerOnly>, fallback: Option<Pubkey>) -> Result<()> {
        let reg = &mut ctx.accounts.registry;
        require_keys_eq!(ctx.accounts.signer.key(), reg.owner, ErrorCode::Unauthorized);
        reg.fallback_registry = fallback;
        Ok(())
    }

    // Anyone: adopt safe harbor by associating their wallet with an agreement account
    pub fn adopt_safe_harbor(ctx: Context<AdoptSafeHarbor>) -> Result<()> {
        let reg = &mut ctx.accounts.registry;
        let adopter = ctx.accounts.adopter.key();
        let old_agreement = reg.agreements.get(adopter);
        reg.agreements.insert(adopter, ctx.accounts.agreement.key());
        
        emit!(SafeHarborAdoption {
            entity: adopter,
            old_details: old_agreement.unwrap_or_default(),
            new_details: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Get agreement for an adopter (with fallback registry support)
    pub fn get_agreement(ctx: Context<GetAgreement>, adopter: Pubkey) -> Result<Pubkey> {
        let reg = &ctx.accounts.registry;
        
        if let Some(agreement) = reg.agreements.get(adopter) {
            return Ok(agreement);
        }
        
        // TODO: Implement fallback registry lookup if needed
        // For now, we'll return an error if no agreement is found
        err!(ErrorCode::NoAgreement)
    }

    // Check if a chain is valid
    pub fn is_chain_valid(ctx: Context<ReadOnlyRegistry>, caip2_chain_id: String) -> Result<bool> {
        let reg = &ctx.accounts.registry;
        Ok(reg.valid_chains.contains(&caip2_chain_id))
    }

    // Get all valid chains
    pub fn get_valid_chains(ctx: Context<ReadOnlyRegistry>) -> Result<Vec<String>> {
        let reg = &ctx.accounts.registry;
        Ok(reg.valid_chains.clone())
    }

    // Create an Agreement account with initial details and set authority/owner
    pub fn create_agreement(
        ctx: Context<CreateAgreement>,
        params: AgreementInitParams,
    ) -> Result<()> {
        let agreement = &mut ctx.accounts.agreement;
        let registry = &ctx.accounts.registry;

        // Validate chains exist
        for ch in params.chains.iter() {
            require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
        }
        // Validate bounty terms
        require!(!(params.bounty_terms.aggregate_bounty_cap_usd > 0 && params.bounty_terms.retainable), ErrorCode::CannotSetBothAggregateBountyCapUSDAndRetainable);
        
        // Validate no duplicate chain IDs
        validate_no_duplicate_chain_ids(&params.chains)?;

        agreement.owner = ctx.accounts.owner.key();
        agreement.protocol_name = params.protocol_name;
        agreement.contact_details = params.contact_details;
        agreement.chains = params.chains;
        agreement.bounty_terms = params.bounty_terms;
        agreement.agreement_uri = params.agreement_uri;
        
        // Calculate required space and resize if needed
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: set protocol name
    pub fn set_protocol_name(ctx: Context<AgreementOwnerOnly>, protocol_name: String) -> Result<()> {
        require!(!protocol_name.is_empty(), ErrorCode::InvalidInput);
        require!(protocol_name.len() <= 128, ErrorCode::InvalidInput);
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        agreement.protocol_name = protocol_name;
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: set contact details
    pub fn set_contact_details(ctx: Context<AgreementOwnerOnly>, contacts: Vec<Contact>) -> Result<()> {
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        agreement.contact_details = contacts;
        
        // Resize account if needed
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: add multiple chains (must be valid and not cause duplicate CAIP-2 IDs)
    pub fn add_chains(ctx: Context<AgreementOwnerWithRegistry>, chains: Vec<Chain>) -> Result<()> {
        let registry = &ctx.accounts.registry;
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        
        // Validate chain ids are valid per registry
        for ch in chains.iter() {
            require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
        }
        
        // Append chains
        for ch in chains.into_iter() {
            agreement.chains.push(ch);
        }
        
        // Ensure no duplicates across all chains
        validate_no_duplicate_chain_ids(&agreement.chains)?;
        
        // Resize account to accommodate new data
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: set/replace specific chains by CAIP-2 ID
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
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: remove multiple chains by CAIP-2 IDs
    pub fn remove_chains(ctx: Context<AgreementOwnerOnly>, ids: Vec<String>) -> Result<()> {
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        for id in ids.into_iter() {
            let idx = find_chain_index(&agreement.chains, &id)?;
            agreement.chains.swap_remove(idx);
        }
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: add accounts to a specific chain
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
        
        // Resize account to accommodate new data
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: remove accounts by address strings from a specific chain
    pub fn remove_accounts(
        ctx: Context<AgreementOwnerOnly>,
        caip2_chain_id: String,
        account_addresses: Vec<String>,
    ) -> Result<()> {
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        let idx = find_chain_index(&agreement.chains, &caip2_chain_id)?;
        for addr in account_addresses.into_iter() {
            let acc_idx = find_account_index(&agreement.chains[idx].accounts, &addr, &agreement.chains[idx].caip2_chain_id)?;
            agreement.chains[idx].accounts.swap_remove(acc_idx);
        }
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: set bounty terms (with validation)
    pub fn set_bounty_terms(ctx: Context<AgreementOwnerOnly>, terms: BountyTerms) -> Result<()> {
        require!(!(terms.aggregate_bounty_cap_usd > 0 && terms.retainable), ErrorCode::CannotSetBothAggregateBountyCapUSDAndRetainable);
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        agreement.bounty_terms = terms;
        
        // Resize account if needed
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Owner-only: set agreement URI
    pub fn set_agreement_uri(ctx: Context<AgreementOwnerOnly>, agreement_uri: String) -> Result<()> {
        require!(!agreement_uri.is_empty(), ErrorCode::InvalidInput);
        assert_agreement_owner(ctx.accounts.owner.key(), &ctx.accounts.agreement)?;
        let agreement = &mut ctx.accounts.agreement;
        agreement.agreement_uri = agreement_uri;
        
        // Resize account if needed
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        Ok(())
    }

    // Factory function: create agreement and adopt in one transaction
    pub fn create_and_adopt_agreement(
        ctx: Context<CreateAndAdoptAgreement>,
        params: AgreementInitParams,
    ) -> Result<()> {
        let registry = &mut ctx.accounts.registry;
        let agreement = &mut ctx.accounts.agreement;
        let adopter = ctx.accounts.adopter.key();

        // Validate chains exist
        for ch in params.chains.iter() {
            require!(registry.valid_chains.contains(&ch.caip2_chain_id), ErrorCode::InvalidChainId);
        }
        // Validate bounty terms
        require!(!(params.bounty_terms.aggregate_bounty_cap_usd > 0 && params.bounty_terms.retainable), ErrorCode::CannotSetBothAggregateBountyCapUSDAndRetainable);
        
        // Validate no duplicate chain IDs
        validate_no_duplicate_chain_ids(&params.chains)?;

        // Initialize agreement
        agreement.owner = ctx.accounts.owner.key();
        agreement.protocol_name = params.protocol_name;
        agreement.contact_details = params.contact_details;
        agreement.chains = params.chains;
        agreement.bounty_terms = params.bounty_terms;
        agreement.agreement_uri = params.agreement_uri;
        
        // Calculate required space and resize if needed
        let required_space = agreement.calculate_required_space();
        if ctx.accounts.agreement.to_account_info().data_len() < required_space {
            ctx.accounts.agreement.to_account_info().realloc(required_space, false)?;
        }
        
        // Adopt the agreement
        let old_agreement = registry.agreements.get(adopter);
        registry.agreements.insert(adopter, ctx.accounts.agreement.key());
        
        emit!(AgreementUpdated {
            agreement: ctx.accounts.agreement.key(),
        });
        
        emit!(SafeHarborAdoption {
            entity: adopter,
            old_details: old_agreement.unwrap_or_default(),
            new_details: ctx.accounts.agreement.key(),
        });
        
        Ok(())
    }

    // Get agreement details (view function)
    pub fn get_agreement_details(_ctx: Context<ReadOnlyAgreement>) -> Result<()> {
        // In Solana, we typically don't return complex data structures directly
        // Instead, clients read the account data directly
        // This function serves as a validation that the agreement exists and is readable
        Ok(())
    }
}

// -------------------- Accounts --------------------

#[account]
pub struct Registry {
    pub owner: Pubkey,
    pub fallback_registry: Option<Pubkey>,
    // Mapping adopter -> agreement account address
    // We approximate mapping via a vector of pairs in a small-scale MVP using an AccountMap helper.
    pub agreements: AccountMap,
    // Valid chain IDs (CAIP-2 strings). We pre-allocate space generously for localnet usage.
    pub valid_chains: Vec<String>,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AccountMapEntry {
    pub key: Pubkey,
    pub value: Pubkey,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AccountMap {
    pub items: Vec<AccountMapEntry>,
}

impl AccountMap {
    pub fn insert(&mut self, key: Pubkey, value: Pubkey) {
        if let Some(i) = self.items.iter().position(|e| e.key == key) {
            self.items[i].value = value;
        } else {
            self.items.push(AccountMapEntry { key, value });
        }
    }

    #[allow(dead_code)]
    pub fn get(&self, key: Pubkey) -> Option<Pubkey> {
        self.items.iter().find(|e| e.key == key).map(|e| e.value)
    }
}

#[account]
pub struct Agreement {
    pub owner: Pubkey,
    pub protocol_name: String,
    pub contact_details: Vec<Contact>,
    pub chains: Vec<Chain>,
    pub bounty_terms: BountyTerms,
    pub agreement_uri: String,
}

// -------------------- Data Types --------------------

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct Contact {
    pub name: String,
    pub contact: String,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct Chain {
    pub asset_recovery_address: String,
    pub accounts: Vec<AccountInScope>,
    pub caip2_chain_id: String,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub enum ChildContractScope {
    None,
    ExistingOnly,
    All,
    FutureOnly,
}
impl Default for ChildContractScope {
    fn default() -> Self { Self::None }
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AccountInScope {
    pub account_address: String,
    pub child_contract_scope: ChildContractScope,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub enum IdentityRequirements {
    Anonymous,
    Pseudonymous,
    Named,
}
impl Default for IdentityRequirements {
    fn default() -> Self { Self::Anonymous }
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct BountyTerms {
    pub bounty_percentage: u64,
    pub bounty_cap_usd: u64,
    pub retainable: bool,
    pub identity: IdentityRequirements,
    pub diligence_requirements: String,
    pub aggregate_bounty_cap_usd: u64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AgreementInitParams {
    pub protocol_name: String,
    pub contact_details: Vec<Contact>,
    pub chains: Vec<Chain>,
    pub bounty_terms: BountyTerms,
    pub agreement_uri: String,
}

// -------------------- Contexts --------------------

#[derive(Accounts)]
pub struct InitializeRegistry<'info> {
    #[account(
        init,
        payer = payer,
        space = Registry::MAX_SPACE,
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
    /// The adopter (any signer)
    pub adopter: Signer<'info>,
    /// CHECK: agreement PDA or normal account; stored as pubkey only
    pub agreement: UncheckedAccount<'info>,
}

#[derive(Accounts)]
pub struct CreateAgreement<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    #[account(
        init,
        payer = payer,
        space = Agreement::INITIAL_SPACE,
        // In this first pass we create agreement as a regular account; clients can choose PDAs later if desired.
    )]
    pub agreement: Account<'info, Agreement>,
    /// The agreement owner/authority
    pub owner: Signer<'info>,
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
        payer = payer,
        space = Agreement::INITIAL_SPACE,
    )]
    pub agreement: Account<'info, Agreement>,
    /// The agreement owner/authority
    pub owner: Signer<'info>,
    /// The adopter (can be same as owner)
    pub adopter: Signer<'info>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AgreementOwnerOnly<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct AgreementOwnerWithRegistry<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
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
pub struct ReadOnlyAgreement<'info> {
    pub agreement: Account<'info, Agreement>,
}

// (removed params_hash; not used in this version)

// -------------------- Sizes --------------------
impl Registry {
    pub const MAX_VALID_CHAINS: usize = 32; // reduced for space efficiency
    pub const AVG_CHAIN_ID_LEN: usize = 32; // reduced average chain ID length
    pub const AGREEMENTS_CAP: usize = 64; // reduced for initial deployment

    pub const MAX_SPACE: usize = 8  // discriminator
        + 32 // owner
        + 1 + 32 // Option<Pubkey>
        + 4 + (Self::AGREEMENTS_CAP * (32 + 32)) // AccountMap as Vec<Entry>
        + 4 + (Self::MAX_VALID_CHAINS * (4 + Self::AVG_CHAIN_ID_LEN)) // Vec<String>
        ;
}

impl Agreement {
    // Base space for empty agreement (discriminator + fixed fields)
    pub const BASE_SPACE: usize = 8 // discriminator
        + 32 // owner
        + 4 // protocol_name length
        + 4 // contact_details vec length
        + 4 // chains vec length
        + 8 + 8 + 1 + 1 + 4 + 8 // bounty terms (all numeric fields + bools + enum)
        + 4; // agreement_uri length
    
    // Initial space allocation - will grow dynamically
    pub const INITIAL_SPACE: usize = Self::BASE_SPACE + 1024; // 1KB buffer for initial data
    
    // Calculate the actual space needed for current data
    pub fn calculate_required_space(&self) -> usize {
        let mut size = Self::BASE_SPACE;
        
        // Protocol name
        size += self.protocol_name.len();
        
        // Contact details
        for contact in &self.contact_details {
            size += 4 + contact.name.len() + 4 + contact.contact.len();
        }
        
        // Chains
        for chain in &self.chains {
            size += 4 + chain.asset_recovery_address.len(); // asset recovery address
            size += 4; // accounts vec length
            
            // Accounts in this chain
            for account in &chain.accounts {
                size += 4 + account.account_address.len() + 1; // address + enum
            }
            
            size += 4 + chain.caip2_chain_id.len(); // chain id
        }
        
        // Bounty terms diligence requirements
        size += self.bounty_terms.diligence_requirements.len();
        
        // Agreement URI
        size += self.agreement_uri.len();
        
        // Add 25% buffer for safety
        size + (size / 4)
    }
}

// -------------------- Access Control --------------------

#[error_code]
pub enum ErrorCode {
    #[msg("Unauthorized")] 
    Unauthorized,
    #[msg("Invalid chain id")] 
    InvalidChainId,
    #[msg("Cannot set both aggregateBountyCapUSD and retainable")] 
    CannotSetBothAggregateBountyCapUSDAndRetainable,
    #[msg("Chain not found")] 
    ChainNotFound,
    #[msg("Account not found")] 
    AccountNotFound,
    #[msg("Duplicate chain id")] 
    DuplicateChainId,
    #[msg("No agreement found")]
    NoAgreement,
    #[msg("Invalid input")]
    InvalidInput,
}

// -------------------- Events --------------------

#[event]
pub struct RegistryInitialized {
    pub owner: Pubkey,
}

#[event]
pub struct SafeHarborAdoption {
    pub entity: Pubkey,
    pub old_details: Pubkey,
    pub new_details: Pubkey,
}

#[event]
pub struct ChainValiditySet {
    pub caip2_chain_id: String,
    pub valid: bool,
}

#[event]
pub struct AgreementUpdated {
    pub agreement: Pubkey,
}

// -------------------- Helpers --------------------
fn assert_agreement_owner(owner: Pubkey, agreement: &Account<Agreement>) -> Result<()> {
    require_keys_eq!(owner, agreement.owner, ErrorCode::Unauthorized);
    Ok(())
}
fn validate_no_duplicate_chain_ids(chains: &[Chain]) -> Result<()> {
    for i in 0..chains.len() {
        for j in (i+1)..chains.len() {
            if chains[i].caip2_chain_id == chains[j].caip2_chain_id {
                return err!(ErrorCode::DuplicateChainId);
            }
        }
    }
    Ok(())
}

fn find_chain_index(chains: &[Chain], id: &str) -> Result<usize> {
    chains.iter().position(|c| c.caip2_chain_id == id).ok_or(ErrorCode::ChainNotFound.into())
}

fn find_account_index(accounts: &[AccountInScope], addr: &str, _chain_id: &str) -> Result<usize> {
    accounts.iter().position(|a| a.account_address == addr).ok_or(ErrorCode::AccountNotFound.into())
}
