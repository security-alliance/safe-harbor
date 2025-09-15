use anchor_lang::prelude::*;

#[event]
pub struct RegistryInitialized {
    pub owner: Pubkey,
}

#[event]
pub struct SafeHarborAdoption {
    pub entity: Pubkey,
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


