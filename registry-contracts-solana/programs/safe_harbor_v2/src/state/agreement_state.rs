use anchor_lang::prelude::*;

#[account]
#[derive(InitSpace)]
pub struct Agreement {
    pub version: u8,
    pub owner: Pubkey,
    #[max_len(100)]
    pub protocol_name: String,
    pub contact_details: [Contact; 10],
    pub asset_recovery_address: Pubkey,
    pub bounty_terms: BountyTerms,
    #[max_len(100)]
    pub agreement_uri: String,
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub struct Contact {
    #[max_len(100)]
    pub name: String,
    #[max_len(100)]
    pub contact: String,
}

#[account]
#[derive(InitSpace)]
pub struct AccountRecord {
    pub account_address: Pubkey,
    pub child_contract_scope: ChildContractScope,
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub struct BountyTerms {
    pub bounty_percentage: u64,
    pub bounty_cap_usd: u64,
    pub retainable: bool,
    pub identity: u8,
    #[max_len(100)]
    pub diligence_requirements: String,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub enum ChildContractScope {
    None,
    ExistingOnly,
    All,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub enum IdentityRequirements {
    Anonymous,
    Pseudonymous,
    Named,
}
