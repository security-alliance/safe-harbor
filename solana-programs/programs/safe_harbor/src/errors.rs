use anchor_lang::prelude::*;

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


