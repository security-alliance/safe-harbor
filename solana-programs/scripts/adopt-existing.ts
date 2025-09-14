import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, SystemProgram } from "@solana/web3.js";
import { SafeHarbor } from "../target/types/safe_harbor";

async function main() {
    if (process.argv.includes("--help") || process.argv.includes("-h")) {
        console.log(`
🤝 Adopt Existing Agreement

Usage:
  npx ts-node scripts/adopt-existing.ts <agreement>

Env:
  ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
  ANCHOR_WALLET=./owner-keypair.json   # adopter wallet
  ADOPTION_SEED_PREFIX=adoption_v2     # optional override (default adoption_v2)
`);
        return;
    }

    const [agreementArg] = process.argv.slice(2);
    if (!agreementArg) {
        console.error("Usage: npx ts-node scripts/adopt-existing.ts <agreement>");
        process.exit(1);
    }

    let agreement: PublicKey;
    try {
        agreement = new PublicKey(agreementArg);
    } catch (e) {
        console.error("❌ Invalid agreement address:", agreementArg);
        process.exit(1);
    }

    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);
    const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

    const adopter = provider.wallet.publicKey;
    const [registryPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("registry")],
        program.programId
    );

    const seedPrefix = process.env.ADOPTION_SEED_PREFIX || "adoption_v2";
    const [adoptionPda] = PublicKey.findProgramAddressSync(
        [Buffer.from(seedPrefix), adopter.toBuffer(), agreement.toBuffer()],
        program.programId
    );
    const [adoptionHead] = PublicKey.findProgramAddressSync(
        [Buffer.from("adoption_head"), adopter.toBuffer()],
        program.programId
    );

    console.log("Registry:", registryPda.toString());
    console.log("Adopter:", adopter.toString());
    console.log("Agreement:", agreement.toString());
    console.log("Adoption PDA:", adoptionPda.toString());
    console.log("Adoption Head:", adoptionHead.toString());

    try {
        const sig = await program.methods
            .adoptSafeHarbor()
            .accountsPartial({
                registry: registryPda,
                adopter,
                agreement,
                adoption: adoptionPda,
                adoptionHead,
                systemProgram: SystemProgram.programId,
            })
            .rpc();

        console.log("✅ Adopted!", sig);

        // Optional sanity read using the new adopter-keyed PDA instruction
        try {
            const resolved = await program.methods
                .getAgreementForAdopter()
                .accountsPartial({ adopter, adoptionHead })
                .view();
            console.log("🔎 Resolved adopter → agreement:", resolved.toString());
        } catch (_) { }
    } catch (err: any) {
        console.error("❌ Adopt failed:", err?.message || err);
        if (err?.logs) console.error("Logs:", err.logs);
        process.exit(1);
    }
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});


