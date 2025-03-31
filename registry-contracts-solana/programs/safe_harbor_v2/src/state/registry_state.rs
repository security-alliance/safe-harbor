use anchor_lang::prelude::*;

#[account]
#[derive(InitSpace)]
pub struct AdoptionRecord {
    pub authority: Pubkey,
    pub agreement: Pubkey,
    pub timestamp: i64,
}
