use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("Invalid chain")]
    InvalidChain,
    #[msg("Account not found")]
    AccountNotFound,
    #[msg("Chain already exists")]
    ChainAlreadyExists,
}
