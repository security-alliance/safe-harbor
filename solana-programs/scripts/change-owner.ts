import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { SafeHarbor } from "../target/types/safe_harbor";
import { PublicKey } from "@solana/web3.js";

async function main() {
    if (process.argv.includes("--help") || process.argv.includes("-h")) {
        console.log(`
🔑 Change Agreement Owner

Usage:
  npx ts-node scripts/change-owner.ts <agreement> <newOwner>

Env:
  ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
  ANCHOR_WALLET=./owner-keypair.json   # current owner must sign
`);
        return;
    }

    const [agreementArg, newOwnerArg] = process.argv.slice(2);
    if (!agreementArg || !newOwnerArg) {
        console.error("Usage: npx ts-node scripts/change-owner.ts <agreement> <newOwner>");
        process.exit(1);
    }

    const agreement = new PublicKey(agreementArg);
    const newOwner = new PublicKey(newOwnerArg);

    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);
    const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

    await program.methods
        .transferOwnership(newOwner)
        .accounts({ agreement, owner: provider.wallet.publicKey })
        .rpc();

    console.log("✅ Ownership updated");
}

main().catch((err) => {
    console.error("❌ Change owner failed:", err);
    process.exit(1);
});


