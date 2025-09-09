use anchor_lang::prelude::*;

use crate::types::{Contact, Chain, BountyTerms};

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AccountMapEntry {
    pub key: Pubkey,
    pub value: Pubkey,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct AccountMap {
    pub items: Vec<AccountMapEntry>,
}

impl AccountMap {
    pub fn insert(&mut self, key: Pubkey, value: Pubkey) {
        if let Some(i) = self.items.iter().position(|e| e.key == key) {
            self.items[i].value = value;
        } else {
            self.items.push(AccountMapEntry { key, value });
        }
    }

    pub fn get(&self, key: Pubkey) -> Option<Pubkey> {
        self.items.iter().find(|e| e.key == key).map(|e| e.value)
    }
}

#[account]
pub struct Registry {
    pub owner: Pubkey,
    pub fallback_registry: Option<Pubkey>,
    pub agreements: AccountMap,
    pub valid_chains: Vec<String>,
}

#[account]
pub struct Agreement {
    pub owner: Pubkey,
    pub protocol_name: String,
    pub contact_details: Vec<Contact>,
    pub chains: Vec<Chain>,
    pub bounty_terms: BountyTerms,
    pub agreement_uri: String,
}

impl Registry {
    pub const BASE_SPACE: usize = 8
        + 32
        + 1 + 32
        + 4
        + 4;

    pub const INITIAL_SPACE: usize = Self::BASE_SPACE + 1024;

    pub fn calculate_required_space(&self) -> usize {
        let mut size = Self::BASE_SPACE;

        size += self.agreements.items.len() * (32 + 32);

        for chain in &self.valid_chains {
            size += 4 + chain.len();
        }

        size + (size / 4)
    }
}

impl Agreement {
    pub const BASE_SPACE: usize = 8
        + 32
        + 4
        + 4
        + 4
        + 8 + 8 + 1 + 1 + 4 + 8
        + 4;

    pub const INITIAL_SPACE: usize = Self::BASE_SPACE + 1024;

    pub fn calculate_required_space(&self) -> usize {
        let mut size = Self::BASE_SPACE;

        size += self.protocol_name.len();

        for contact in &self.contact_details {
            size += 4 + contact.name.len() + 4 + contact.contact.len();
        }

        for chain in &self.chains {
            size += 4 + chain.asset_recovery_address.len();
            size += 4;

            for account in &chain.accounts {
                size += 4 + account.account_address.len() + 1;
            }

            size += 4 + chain.caip2_chain_id.len();
        }

        size += self.bounty_terms.diligence_requirements.len();

        size += self.agreement_uri.len();

        size + (size / 4)
    }
}


