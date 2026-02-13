#!/usr/bin/env node
import { createLocalViemSigner, type PreparedTx } from "./index.js";

function _readArg(flag: string): string | undefined {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

function _hasFlag(flag: string): boolean {
  return process.argv.includes(flag);
}

function _usage(): string {
  return [
    "Usage:",
    "  viem-local-signer address",
    "  viem-local-signer sign-raw --tx-json '<json>'",
    "  viem-local-signer sign-raw --tx-file /path/to/tx.json",
    "  viem-local-signer send-signed --signed-tx <0x...> [--wait]",
  ].join("\n");
}
type RawPreparedTx = Record<string, unknown>;

function _coercePreparedTx(tx: RawPreparedTx): PreparedTx {
  const bigintFields = [
    "value",
    "gas",
    "gasPrice",
    "maxFeePerGas",
    "maxPriorityFeePerGas",
  ];
  for (const field of bigintFields) {
    const value = tx[field];
    if (typeof value === "string" && value.trim() !== "") tx[field] = BigInt(value);
    if (typeof value === "number") tx[field] = BigInt(value);
  }
  const nonce = tx.nonce;
  if (typeof nonce === "string" && nonce.trim() !== "") tx.nonce = Number(nonce);
  const chainId = tx.chainId;
  if (typeof chainId === "string" && chainId.trim() !== "") tx.chainId = Number(chainId);
  return tx as unknown as PreparedTx;
}

async function _main(): Promise<void> {
  const command = process.argv[2];
  if (!command || command === "--help" || command === "-h" || command === "help") {
    console.log(_usage());
    process.exit(0);
  }

  const signer = createLocalViemSigner();

  if (command === "address") {
    console.log(signer.account);
    return;
  }

  if (command === "sign-raw") {
    const txJson = _readArg("--tx-json");
    const txFile = _readArg("--tx-file");
    if (!txJson && !txFile) throw new Error("Missing required --tx-json or --tx-file");
    const parsedRaw = txFile
      ? JSON.parse(await (await import("node:fs/promises")).readFile(txFile, "utf-8"))
      : JSON.parse(txJson ?? "{}");
    const preparedTx = _coercePreparedTx(parsedRaw);
    const signed = await signer.signPreparedTransaction(preparedTx);
    console.log(
      JSON.stringify(
        {
          status: "signed",
          hash: signed.hash,
          serializedTransaction: signed.serializedTransaction,
        },
        null,
        2
      )
    );
    return;
  }

  if (command === "send-signed") {
    const serializedTransaction = _readArg("--signed-tx");
    if (!serializedTransaction) {
      throw new Error("Missing required --signed-tx argument");
    }
    const wait = _hasFlag("--wait");
    const hash = await signer.sendSignedTransaction(serializedTransaction as `0x${string}`);
    if (!wait) {
      console.log(JSON.stringify({ hash, status: "submitted" }, null, 2));
      return;
    }
    const receipt = await signer.waitFor(hash);
    console.log(
      JSON.stringify(
        {
          hash,
          status: receipt.status,
          blockNumber: receipt.blockNumber.toString(),
          gasUsed: receipt.gasUsed.toString(),
        },
        null,
        2
      )
    );
    return;
  }

  console.error(`Unknown command: ${command}`);
  console.log(_usage());
  process.exit(1);
}

_main().catch((err) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(`viem-local-signer error: ${message}`);
  process.exit(1);
});
