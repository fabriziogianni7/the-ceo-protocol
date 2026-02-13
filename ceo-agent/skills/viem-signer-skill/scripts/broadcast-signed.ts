#!/usr/bin/env node
import { requireArg, parseArgs, sendSignedTransaction } from "./common.js";

async function main() {
  const args = parseArgs(process.argv);
  const signedTx = requireArg(args, "signed-tx") as `0x${string}`;
  const wait = Boolean(args.wait);
  const result = await sendSignedTransaction(signedTx, wait);
  console.log(JSON.stringify({ status: "ok", ...result }, null, 2));
}

main().catch((err) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(`broadcast-signed.ts error: ${message}`);
  process.exit(1);
});
