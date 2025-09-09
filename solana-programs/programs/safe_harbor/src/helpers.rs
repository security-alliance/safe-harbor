use anchor_lang::prelude::*;

use crate::errors::ErrorCode;
use crate::state::{Agreement};
use crate::types::{Chain, AccountInScope};

pub const VERSION: &str = "1.1.0";

pub fn assert_agreement_owner(owner: Pubkey, agreement: &Account<Agreement>) -> Result<()> {
    require_keys_eq!(owner, agreement.owner, ErrorCode::Unauthorized);
    Ok(())
}

pub fn validate_no_duplicate_chain_ids(chains: &[Chain]) -> Result<()> {
    for i in 0..chains.len() {
        for j in (i+1)..chains.len() {
            if chains[i].caip2_chain_id == chains[j].caip2_chain_id {
                return err!(ErrorCode::DuplicateChainId);
            }
        }
    }
    Ok(())
}

pub fn find_chain_index(chains: &[Chain], id: &str) -> Result<usize> {
    chains.iter().position(|c| c.caip2_chain_id == id).ok_or(ErrorCode::ChainNotFound.into())
}

pub fn find_account_index(accounts: &[AccountInScope], addr: &str) -> Result<usize> {
    accounts.iter().position(|a| a.account_address == addr).ok_or(ErrorCode::AccountNotFound.into())
}

pub fn resize_if_needed(account_info: &AccountInfo, required_space: usize) -> Result<()> {
    if account_info.data_len() < required_space {
        account_info.resize(required_space)?;
    }
    Ok(())
}


#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{Chain, AccountInScope};

    #[test]
    fn validate_no_duplicate_chain_ids_ok() {
        let chains = vec![
            Chain { asset_recovery_address: "x".into(), accounts: vec![], caip2_chain_id: "eip155:1".into() },
            Chain { asset_recovery_address: "y".into(), accounts: vec![], caip2_chain_id: "eip155:137".into() },
        ];
        assert!(validate_no_duplicate_chain_ids(&chains).is_ok());
    }

    #[test]
    fn validate_no_duplicate_chain_ids_err() {
        let chains = vec![
            Chain { asset_recovery_address: "x".into(), accounts: vec![], caip2_chain_id: "eip155:1".into() },
            Chain { asset_recovery_address: "y".into(), accounts: vec![], caip2_chain_id: "eip155:1".into() },
        ];
        assert!(validate_no_duplicate_chain_ids(&chains).is_err());
    }

    #[test]
    fn find_chain_index_works() {
        let chains = vec![
            Chain { asset_recovery_address: "x".into(), accounts: vec![], caip2_chain_id: "eip155:1".into() },
            Chain { asset_recovery_address: "y".into(), accounts: vec![], caip2_chain_id: "eip155:137".into() },
        ];
        assert_eq!(find_chain_index(&chains, "eip155:137").unwrap(), 1);
        assert!(find_chain_index(&chains, "eip155:2").is_err());
    }

    #[test]
    fn find_account_index_works() {
        let accounts = vec![
            AccountInScope { account_address: "0x01".into(), child_contract_scope: Default::default() },
            AccountInScope { account_address: "0x02".into(), child_contract_scope: Default::default() },
        ];
        assert_eq!(find_account_index(&accounts, "0x02").unwrap(), 1);
        assert!(find_account_index(&accounts, "0x03").is_err());
    }
}
