use anchor_lang::prelude::*;

use crate::state::{Registry, Agreement};

#[derive(Accounts)]
pub struct InitializeRegistry<'info> {
    #[account(
        init,
        payer = payer,
        space = Registry::INITIAL_SPACE,
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
    )]
    pub agreement: Account<'info, Agreement>,
    /// CHECK: Owner can be any valid pubkey, doesn't need to sign for creation
    pub owner: UncheckedAccount<'info>,
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
    /// CHECK: Owner can be any valid pubkey, doesn't need to sign for creation
    pub owner: UncheckedAccount<'info>,
    pub adopter: Signer<'info>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AgreementOwnerOnly<'info> {
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,
    /// CHECK: The owner account is validated against the agreement's owner field
    pub owner: UncheckedAccount<'info>,
}

#[derive(Accounts)]
pub struct AgreementOwnerWithRegistry<'info> {
    #[account(mut, seeds=[b"registry"], bump)]
    pub registry: Account<'info, Registry>,
    #[account(mut)]
    pub agreement: Account<'info, Agreement>,
    /// CHECK: The owner account is validated against the agreement's owner field
    pub owner: UncheckedAccount<'info>,
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


