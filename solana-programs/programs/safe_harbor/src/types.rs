use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct Contact {
    pub name: String,
    pub contact: String,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AccountInScope {
    pub account_address: String,
    pub child_contract_scope: ChildContractScope,
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


