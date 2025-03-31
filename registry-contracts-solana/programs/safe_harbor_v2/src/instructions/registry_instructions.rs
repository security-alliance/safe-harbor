use crate::{event::SafeHarborAdoptionEvent, AdoptionRecord};
use anchor_lang::prelude::*;

pub fn adopt_safe_harbor_handler(ctx: Context<AdoptSafeHarbor>, agreement: Pubkey) -> Result<()> {
    ctx.accounts.adoption_record.authority = ctx.accounts.authority.key();
    ctx.accounts.adoption_record.agreement = agreement;
    ctx.accounts.adoption_record.timestamp = Clock::get()?.unix_timestamp;

    emit!(SafeHarborAdoptionEvent {
        authority: ctx.accounts.authority.key(),
        agreement,
    });

    Ok(())
}

#[derive(Accounts)]
pub struct AdoptSafeHarbor<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init_if_needed,
        payer = authority,
        space = 8 + AdoptionRecord::INIT_SPACE,
        seeds = [b"adoption", authority.key().as_ref()],
        bump
    )]
    pub adoption_record: Account<'info, AdoptionRecord>,

    pub system_program: Program<'info, System>,
}
