import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import { expect } from "chai";

// Helper types matching Rust structs
type Contact = { name: string; contact: string };
type AccountInScope = { accountAddress: string; childContractScope: { [k: string]: {} } | number };
type Chain = { assetRecoveryAddress: string; accounts: AccountInScope[]; caip2ChainId: string };
type BountyTerms = {
  bountyPercentage: number;
  bountyCapUsd: number;
  retainable: boolean;
  identity: { [k: string]: {} } | number;
  diligenceRequirements: string;
  aggregateBountyCapUsd: number;
};

type AgreementInitParams = {
  protocolName: string;
  contactDetails: Contact[];
  chains: Chain[];
  bountyTerms: BountyTerms;
  agreementUri: string;
};

// Encode enums as numeric variants to match Anchor's representation
const ChildContractScope = {
  None: 0,
  ExistingOnly: 1,
  All: 2,
  FutureOnly: 3,
} as const;

const IdentityRequirements = {
  Anonymous: 0,
  Pseudonymous: 1,
  Named: 2,
} as const;

function mockAgreementDetails(accountAddr: string): AgreementInitParams {
  const contact: Contact = { name: "Test Name V2", contact: "test@mail.com" };
  const account: AccountInScope = { accountAddress: accountAddr, childContractScope: ChildContractScope.All };
  const chain: Chain = {
    assetRecoveryAddress: "0x0000000000000000000000000000000000000022",
    caip2ChainId: "eip155:1",
    accounts: [account],
  };
  const bountyTerms: BountyTerms = {
    bountyPercentage: 10,
    bountyCapUsd: 100,
    retainable: false,
    identity: IdentityRequirements.Anonymous,
    diligenceRequirements: "none",
    aggregateBountyCapUsd: 1000,
  };
  return {
    protocolName: "testProtocolV2",
    contactDetails: [contact],
    chains: [chain],
    bountyTerms,
    agreementUri: "ipfs://testHash",
  };
}

describe("safe_harbor", () => {
  const provider = anchor.AnchorProvider.local();
  anchor.setProvider(provider);

  const program = anchor.workspace.safe_harbor as Program;

  const [registryPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("registry")],
    program.programId
  );

  it("initialize registry and set chains", async () => {
    // initialize_registry
    await program.methods
      .initializeRegistry(provider.wallet.publicKey)
      .accounts({ registry: registryPda, payer: provider.wallet.publicKey, systemProgram: SystemProgram.programId })
      .rpc();

    // set_valid_chains
    await program.methods
      .setValidChains(["eip155:1", "eip155:2"]) // OwnerOnly expects signer to be registry.owner
      .accounts({ registry: registryPda, signer: provider.wallet.publicKey })
      .rpc();
  });

  it("create, adopt, and mutate agreement", async () => {
    const agreementKp = Keypair.generate();
    const params = mockAgreementDetails("0xAABB");

    await program.methods
      .createAgreement(params as any)
      .accounts({
        registry: registryPda,
        agreement: agreementKp.publicKey,
        owner: provider.wallet.publicKey,
        payer: provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([agreementKp])
      .rpc();

    // adopt_safe_harbor
    await program.methods
      .adoptSafeHarbor()
      .accounts({ registry: registryPda, adopter: provider.wallet.publicKey, agreement: agreementKp.publicKey })
      .rpc();

    // set_protocol_name
    await program.methods
      .setProtocolName("Updated Protocol")
      .accounts({ agreement: agreementKp.publicKey, owner: provider.wallet.publicKey })
      .rpc();

    // add_accounts to eip155:1
    await program.methods
      .addAccounts("eip155:1", [{ accountAddress: "0x02", childContractScope: ChildContractScope.None }] as any)
      .accounts({ agreement: agreementKp.publicKey, owner: provider.wallet.publicKey })
      .rpc();

    // Fetch agreement account and assert
    const acct: any = await program.account.agreement.fetch(agreementKp.publicKey);
    expect(acct.protocolName).to.eq("Updated Protocol");
    expect(acct.chains.length).to.eq(1);
    const chain = acct.chains[0];
    expect(chain.caip2ChainId).to.eq("eip155:1");
    expect(chain.accounts.length).to.eq(2);
  });
});
