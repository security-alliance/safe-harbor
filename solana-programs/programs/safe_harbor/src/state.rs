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
pub struct AdoptionEntry {
    pub agreement: Pubkey,
}

impl AdoptionEntry {
    pub const SPACE: usize = 8 + 32;
}

#[account]
pub struct AdoptionHead {
    pub agreement: Pubkey,
}

impl AdoptionHead {
    pub const SPACE: usize = 8 + 32;
}


#[account]
pub struct Registry {
    pub owner: Pubkey,
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{Contact, Chain, AccountInScope, BountyTerms, IdentityRequirements};

    fn make_agreement(contacts: usize, chains: usize, accounts_per_chain: usize) -> Agreement {
        let contact_details = (0..contacts).map(|i| Contact { name: format!("n{}", i), contact: format!("c{}", i) }).collect();
        let chains_vec = (0..chains).map(|i| {
            let accounts = (0..accounts_per_chain).map(|j| AccountInScope { account_address: format!("0x{:02x}", j), child_contract_scope: Default::default() }).collect();
            Chain { asset_recovery_address: format!("addr{}", i), accounts, caip2_chain_id: format!("eip155:{}", i+1) }
        }).collect();
        Agreement {
            owner: Pubkey::default(),
            protocol_name: "p".into(),
            contact_details,
            chains: chains_vec,
            bounty_terms: BountyTerms { bounty_percentage: 10, bounty_cap_usd: 100, retainable: false, identity: IdentityRequirements::Anonymous, diligence_requirements: "x".into(), aggregate_bounty_cap_usd: 0 },
            agreement_uri: "ipfs://x".into(),
        }
    }

    #[test]
    fn agreement_space_grows_with_contacts() {
        let mut a = make_agreement(0, 1, 1);
        let base = a.calculate_required_space();
        a.contact_details.push(Contact { name: "A".into(), contact: "B".into() });
        assert!(a.calculate_required_space() > base);
    }

    #[test]
    fn agreement_space_grows_with_accounts() {
        let a1 = make_agreement(0, 1, 0);
        let a2 = make_agreement(0, 1, 3);
        assert!(a2.calculate_required_space() > a1.calculate_required_space());
    }

    #[test]
    fn registry_space_grows_with_valid_chains_and_agreements() {
        let mut r = Registry { owner: Pubkey::default(), agreements: AccountMap { items: vec![] }, valid_chains: vec![] };
        let base = r.calculate_required_space();
        r.valid_chains.push("eip155:1".into());
        let after_chain = r.calculate_required_space();
        assert!(after_chain > base);
        r.agreements.insert(Pubkey::new_unique(), Pubkey::new_unique());
        assert!(r.calculate_required_space() > after_chain);
    }
}


