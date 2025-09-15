import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey } from "@solana/web3.js";
import { SafeHarbor } from "../target/types/safe_harbor";

type ScopeKey = "none" | "existingOnly" | "all" | "futureOnly";

function parseAccounts(arg?: string): any[] {
    if (!arg || !arg.trim()) return [];
    const items = arg.split(",").map((s) => s.trim()).filter(Boolean);
    return items.map((item) => {
        const [addr, rawScope] = item.split(":");
        const rawScopeNormalized = (rawScope || "none").toLowerCase();
        const scope = rawScopeNormalized === "existingonly" ? "existingOnly"
            : rawScopeNormalized === "futureonly" ? "futureOnly"
                : rawScopeNormalized as ScopeKey;
        const scopeObj: any =
            scope === "existingOnly"
                ? { existingOnly: {} }
                : scope === "all"
                    ? { all: {} }
                    : scope === "futureOnly"
                        ? { futureOnly: {} }
                        : { none: {} };
        return { accountAddress: addr, childContractScope: scopeObj };
    });
}

async function main() {
    if (process.argv.includes("--help") || process.argv.includes("-h")) {
        console.log(`
🔗 Add Chain to Agreement

Usage:
  npx ts-node scripts/add-chain.ts <agreement> <caip2ChainId> <assetRecoveryAddress> [accounts]

Args:
  agreement            Agreement pubkey
  caip2ChainId         Chain id (must be in registry valid chains), e.g. eip155:1
  assetRecoveryAddress Address for asset recovery
  accounts             Optional CSV: addr[:scope][,addr[:scope]...]
                       scope ∈ none|existingOnly|all|futureOnly (default none)

Env:
  ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
  ANCHOR_WALLET=./owner-keypair.json
`);
        return;
    }

    const [agreementArg, chainId, assetRecovery, accountsCsv] = process.argv.slice(2);
    if (!agreementArg || !chainId || !assetRecovery) {
        console.error("Usage: npx ts-node scripts/add-chain.ts <agreement> <caip2ChainId> <assetRecoveryAddress> [accounts]");
        process.exit(1);
    }

    const agreement = new PublicKey(agreementArg);
    const accounts = parseAccounts(accountsCsv);

    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);
    const program = anchor.workspace.SafeHarbor as Program<SafeHarbor>;

    // Derive registry PDA (v2 only)
    const [registryPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("registry_v2")],
        program.programId
    );
    console.log("Using Registry PDA:", registryPda.toString());

    const chain: any = {
        caip2ChainId: chainId,
        assetRecoveryAddress: assetRecovery,
        accounts,
    };

    try {
        const sig = await program.methods
            .addChains([chain] as any)
            .accountsPartial({
                registry: registryPda,
                agreement,
                owner: provider.wallet.publicKey,
            })
            .rpc();

        console.log("✅ Chain added", chainId);
        console.log("Tx:", sig);
    } catch (err: any) {
        console.error("❌ Failed to add chain:", err?.message || err);
        if (err?.logs) console.error("Logs:", err.logs);
        process.exit(1);
    }
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});


