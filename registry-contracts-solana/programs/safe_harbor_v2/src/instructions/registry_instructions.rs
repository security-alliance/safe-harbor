use crate::event::SafeHarborAdoptionEvent;
use anchor_lang::prelude::*;

pub fn adopt_safe_harbor_handler(ctx: Context<AdoptSafeHarbor>, agreement: Pubkey) -> Result<()> {
    emit!(SafeHarborAdoptionEvent {
        authority: ctx.accounts.authority.key(),
        agreement,
    });
    Ok(())
}

#[derive(Accounts)]
pub struct AdoptSafeHarbor<'info> {
    pub authority: Signer<'info>,
}
