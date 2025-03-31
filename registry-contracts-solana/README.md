# Registry Contracts Solana

This directory houses the solana "Safe Harbor Registry" program. The program serves the same purpose as the EVM Safe Harbor Registry, but differs in some key ways outlined below.

## Technical Details

The Solana Registry Contracts are built using the Anchor framework. See install instructions [here](https://www.anchor-lang.com/docs/installation). To test the program, use `anchor test`.

There is one program in this system:

-   `safe_harbor_v2` - Used to create, mutate, and delete agreements. Used to adopt agreements.

### Deployment

The `safe_harbor_v2` program is deployed using `anchor deploy`.

### Adoption

1. A protocol creates a PDA for their agreement containing the Safe Harbor Agreement Details using the `create_agreement` function.
2. The protocol adopts the agreement using the `adopt_safe_harbor` method.
3. The registry creates an `AdoptionRecord` which references the authority's and agreement's public keys

#### Updating Agreements

V2 Safe Harbor agreements are mutable, ownable, and deletable. This allows protocols to update their agreement details in-place and delegate the responsibility of maintaining the agreement details to a third-party address.

### Querying Agreements

A full list of all Agreement Records can be queried using the `getProgramAccounts` RPC Method on the `safe_harbor_v2` program, or using Anchor for simplicity.

```ts
const agreementRecords = await program.account.agreement.all();
```

Individual agreements can be queried using their PDA.

```ts
const agreement = await program.account.agreement.fetch(agreementAddress);
```

Different versions may have different `AgreementDetails` structs. All `Agreement` and `SafeHarborRegistry` contracts will include a `version()` method which can be used to infer the `AgreementDetails` structure.

### EVM Differences

1. Safe Harbor Registry

Because of Solana's different storage modal, the registry contract has been modified. Instead of storing a mapping of adopters to agreement addresses, the registry instead acts as a factory for `AdoptionRecord`s. The `adopt_safe_harbor` method initializes or overwrides an `AdoptionRecord` for a given authority, as well as recording the agreement address and current timestamp. This keeps the desired properties of having a 1-1 mapping of adopters to agreements and of allowing adopters to overwride their agreement.

2. Registry Fallback

Because no mapping of adopters to agreements exists on Solana, the registry fallback feature present in EVM instances of the Safe Harbor Registry could not be ported over.

3. Chains

Because Solana is primarily a single-chain ecosystem and doesn't have a standardized `ChainID` system, the `Chain` struct has been removed from the `Agreement` struct. This represents a structural change to the agreement.

4. Signed Accounts

Signed Accounts were removed from the Solana implementation of Safe Harbor. Solana programs cannot hold private keys, and no universal standard like `ERC-1271` exists in Solana to bypass this limitation. Due to their limited utility and high relative complexity, signed accounts were not ported over to the Solana Safe Harbor Registry.
