import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarborV2 } from "../target/types/safe_harbor_v2";
import { expect } from "chai";
import { createMockAgreement, expectAgreementEqual, getAccountPda } from "./utils";

describe("safe_harbor_v2", () => {
    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);

    const program = anchor.workspace.SafeHarborV2 as Program<SafeHarborV2>;

    let authority: anchor.web3.Keypair;
    let nonOwner = anchor.web3.Keypair.generate();

    let agreementAddress: anchor.web3.PublicKey;
    let agreementBump: number;

    let agreement = createMockAgreement(anchor.web3.Keypair.generate().publicKey);

    beforeEach(async () => {
        //* Fund owner account
        authority = anchor.web3.Keypair.generate();
        const sig = await provider.connection.requestAirdrop(authority.publicKey, 1e9);
        await provider.connection.confirmTransaction(sig);

        agreement.owner = authority.publicKey.toBase58();

        //* Fund nonOwner account
        const sig1 = await provider.connection.requestAirdrop(nonOwner.publicKey, 1e9);
        await provider.connection.confirmTransaction(sig1);

        //* Create new agreement
        await program.methods
            .createAgreement(
                agreement.protocolName,
                agreement.contactDetails,
                agreement.assetRecoveryAddress,
                agreement.bountyTerms,
                agreement.agreementUri,
                authority.publicKey
            )
            .accounts({
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        //* Fetch agreement address
        [agreementAddress, agreementBump] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("agreement"), authority.publicKey.toBuffer()],
            program.programId
        );
    });

    it("initializes agreement with expected data", async () => {
        const accountAgreement = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(accountAgreement, agreement);
    });

    it("owner can close the agreement", async () => {
        await program.methods
            .closeAgreement()
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const info = await provider.connection.getAccountInfo(agreementAddress);
        expect(info).to.be.null;
    });

    it("non-owner cannot close the agreement", async () => {
        try {
            await program.methods
                .closeAgreement()
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can transfer ownership", async () => {
        const expectedAgreement = { ...agreement, owner: nonOwner.publicKey.toBase58() };

        await program.methods
            .transferOwnership(nonOwner.publicKey)
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const updated = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated, expectedAgreement);

        // Assert that the new owner can now call methods
        const newName = "new-protocol-name";
        const expectedAgreement2 = { ...expectedAgreement, protocolName: newName };

        await program.methods
            .setProtocolName(newName)
            .accounts({ agreement: agreementAddress, authority: nonOwner.publicKey })
            .signers([nonOwner])
            .rpc();

        const updated2 = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated2, expectedAgreement2);
    });

    it("non-owner cannot transfer ownership", async () => {
        try {
            await program.methods
                .transferOwnership(authority.publicKey)
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can set protocol name", async () => {
        const newName = "new-protocol-name";
        const expectedAgreement = { ...agreement, protocolName: newName };

        await program.methods
            .setProtocolName(newName)
            .accounts({ agreement: agreementAddress, authority: authority.publicKey })
            .signers([authority])
            .rpc();

        const updated = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated, expectedAgreement);
    });

    it("non-owner cannot set protocol name", async () => {
        const newName = "new-protocol-name";

        try {
            await program.methods
                .setProtocolName(newName)
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can set contact details", async () => {
        const newContacts = Array.from({ length: 10 }, () => ({
            name: "Bob",
            contact: "bob@example.com",
        }));
        const expectedAgreement = { ...agreement, contactDetails: newContacts };

        await program.methods
            .setContactDetails(newContacts)
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const updated = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated, expectedAgreement);
    });

    it("non-owner cannot set contact details", async () => {
        const badContacts = Array.from({ length: 10 }, () => ({
            name: "Mallory",
            contact: "mallory@example.com",
        }));

        try {
            await program.methods
                .setContactDetails(badContacts)
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can set asset recovery address", async () => {
        //? Random public key
        const newAddress = new anchor.web3.PublicKey("4BJXYkfvg37zEmBbsacZjeQDpTNx91KppxFJxRqrz48e");
        const expectedAgreement = { ...agreement, assetRecoveryAddress: newAddress };

        await program.methods
            .setAssetRecoveryAddress(newAddress)
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const updated = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated, expectedAgreement);
    });

    it("non-owner cannot set asset recovery address", async () => {
        //? Random public key
        const newAddress = new anchor.web3.PublicKey("4BJXYkfvg37zEmBbsacZjeQDpTNx91KppxFJxRqrz48e");

        try {
            await program.methods
                .setAssetRecoveryAddress(newAddress)
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can set agreement URI", async () => {
        const newUri = "https://example.com/new-uri.json";
        const expectedAgreement = { ...agreement, agreementUri: newUri };

        await program.methods
            .setAgreementUri(newUri)
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const updated = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated, expectedAgreement);
    });

    it("non-owner cannot set agreement URI", async () => {
        const newUri = "https://evil.com/uri.json";

        try {
            await program.methods
                .setAgreementUri(newUri)
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can set bounty terms", async () => {
        const newTerms = {
            bountyPercentage: new anchor.BN(50),
            bountyCapUsd: new anchor.BN(5_000),
            retainable: false,
            identity: 2,
            diligenceRequirements: "KYC + review",
        };
        const expectedAgreement = { ...agreement, bountyTerms: newTerms };

        await program.methods
            .setBountyTerms(newTerms)
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const updated = await program.account.agreement.fetch(agreementAddress);
        expectAgreementEqual(updated, expectedAgreement);
    });

    it("non-owner cannot set bounty terms", async () => {
        const newTerms = {
            bountyPercentage: new anchor.BN(99),
            bountyCapUsd: new anchor.BN(9_999),
            retainable: true,
            identity: 3,
            diligenceRequirements: "None",
        };

        try {
            await program.methods
                .setBountyTerms(newTerms)
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();
            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("owner can add and remove an account", async () => {
        const targetAccount = anchor.web3.Keypair.generate().publicKey;
        const [accountRecordAddress] = getAccountPda(agreementAddress, targetAccount, program.programId);

        await program.methods
            .addAccount(targetAccount, { none: {} })
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        const record = await program.account.accountRecord.fetch(accountRecordAddress);
        expect(record.accountAddress.toBase58()).to.equal(targetAccount.toBase58());

        await program.methods
            .removeAccount()
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
                accountRecord: accountRecordAddress,
            })
            .signers([authority])
            .rpc();

        const info = await provider.connection.getAccountInfo(accountRecordAddress);
        expect(info).to.be.null;
    });

    it("non-owner cannot add an account", async () => {
        const targetAccount = anchor.web3.Keypair.generate().publicKey;

        try {
            await program.methods
                .addAccount(targetAccount, { existingOnly: {} })
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                })
                .signers([nonOwner])
                .rpc();

            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("non-owner cannot remove an account", async () => {
        const targetAccount = anchor.web3.Keypair.generate().publicKey;
        const [accountRecordAddress] = getAccountPda(agreementAddress, targetAccount, program.programId);

        // Add account as owner
        await program.methods
            .addAccount(targetAccount, { all: {} })
            .accounts({
                agreement: agreementAddress,
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        // Attempt to remove as non-owner
        try {
            await program.methods
                .removeAccount()
                .accounts({
                    agreement: agreementAddress,
                    authority: nonOwner.publicKey,
                    accountRecord: accountRecordAddress,
                })
                .signers([nonOwner])
                .rpc();

            expect.fail("Expected Unauthorized error");
        } catch (err: any) {
            expect(err.error.errorCode.code).to.equal("Unauthorized");
        }
    });

    it("emits SafeHarborAdoptionEvent and creates an AdoptionRecord on adoption", async () => {
        //* Arrange
        const [adoptionRecordPda] = await anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("adoption"), authority.publicKey.toBuffer()],
            program.programId
        );

        let eventPromise = new Promise<void>((resolve, reject) => {
            const listener = program.addEventListener("safeHarborAdoptionEvent", (event, _slot) => {
                try {
                    expect(event.agreement.toBase58()).to.equal(agreementAddress.toBase58());
                    expect(event.authority.toBase58()).to.equal(authority.publicKey.toBase58());
                    resolve();
                } catch (err) {
                    reject(err);
                } finally {
                    program.removeEventListener(listener);
                }
            });

            setTimeout(() => {
                program.removeEventListener(listener);
                reject(new Error("Event listener timeout"));
            }, 10000);
        });

        //* Act
        await program.methods
            .adoptSafeHarbor(agreementAddress)
            .accounts({
                authority: authority.publicKey,
            })
            .signers([authority])
            .rpc();

        //* Assert
        await eventPromise;

        const adoptionRecord = await program.account.adoptionRecord.fetch(adoptionRecordPda);
        expect(adoptionRecord.authority.toBase58()).to.equal(authority.publicKey.toBase58());
        expect(adoptionRecord.agreement.toBase58()).to.equal(agreementAddress.toBase58());
        expect(adoptionRecord.timestamp.toNumber()).to.be.greaterThan(0);
    });
});
