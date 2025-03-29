import * as anchor from "@coral-xyz/anchor";
import { expect } from "chai";
import { SafeHarborV2 } from "../target/types/safe_harbor_v2";

export function expectAgreementEqual(actual: any, expected: any) {
    expect(actual.owner.toBase58()).to.equal(expected.owner);
    expect(actual.protocolName).to.equal(expected.protocolName);
    expect(actual.agreementUri).to.equal(expected.agreementUri);

    // Contact details
    expect(actual.contactDetails.length).to.equal(expected.contactDetails.length);
    actual.contactDetails.forEach((c: any, i: number) => {
        expect(c.name).to.equal(expected.contactDetails[i].name);
        expect(c.contact).to.equal(expected.contactDetails[i].contact);
    });

    // Bounty terms
    expect(actual.bountyTerms.bountyPercentage.toNumber()).to.equal(expected.bountyTerms.bountyPercentage.toNumber());
    expect(actual.bountyTerms.bountyCapUsd.toNumber()).to.equal(expected.bountyTerms.bountyCapUsd.toNumber());
    expect(actual.bountyTerms.retainable).to.equal(expected.bountyTerms.retainable);
    expect(actual.bountyTerms.identity).to.equal(expected.bountyTerms.identity);
    expect(actual.bountyTerms.diligenceRequirements).to.equal(expected.bountyTerms.diligenceRequirements);
}

export function getAccountPda(
    agreement: anchor.web3.PublicKey,
    accountAddress: anchor.web3.PublicKey,
    programId: anchor.web3.PublicKey
) {
    return anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("account"), agreement.toBuffer(), accountAddress.toBuffer()],
        programId
    );
}

export function createMockAgreement(owner: anchor.web3.PublicKey) {
    return {
        owner: owner.toBase58(),
        protocolName: "example",
        assetRecoveryAddress: new anchor.web3.PublicKey("5oNDL3swdJJF1g9DzJiZ4ynHXgszjAEpUkxVYejchzrY"),
        contactDetails: Array.from({ length: 10 }, () => ({
            name: "Alice",
            contact: "alice@example.com",
        })),
        bountyTerms: {
            bountyPercentage: new anchor.BN(10),
            bountyCapUsd: new anchor.BN(1_000),
            retainable: true,
            identity: 1,
            diligenceRequirements: "KYB",
        },
        agreementUri: "https://example.com/agreement.json",
    };
}
