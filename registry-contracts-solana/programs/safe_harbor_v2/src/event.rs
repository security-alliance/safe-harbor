use anchor_lang::prelude::*;

#[event]
pub struct AddAccountEvent {
    pub account_address: Pubkey,
}

#[event]
pub struct RemoveAccountEvent {
    pub account_address: Pubkey,
}

#[event]
pub struct SafeHarborUpdateEvent {
    pub agreement: Pubkey,
}

#[event]
pub struct SafeHarborAdoptionEvent {
    pub authority: Pubkey,
    pub agreement: Pubkey,
}
