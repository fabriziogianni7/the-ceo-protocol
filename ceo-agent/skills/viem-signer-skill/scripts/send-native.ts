#!/usr/bin/env node
import { getAddress } from "viem";
import {
  argString,
  parseArgs,
  parseValue,
  requireArg,
  resolvePublicClient,
  sendSignedTransaction,
  signRawTransaction,
  signerAddress,
} from "./common.js";

async function main() {
  const args = parseArgs(process.argv);
  const to = getAddress(requireArg(args, "to"));
  const value = parseValue(args);
  const wait = Boolean(args.wait);

  const { publicClient, chainId } = resolvePublicClient(args);
  const from = await signerAddress();
  const nonce = await publicClient.getTransactionCount({ address: from, blockTag: "pending" });
  const gas = BigInt(argString(args, "gas") ?? "21000");

  const txType = (argString(args, "type") ?? "legacy") as "legacy" | "eip1559";
  const baseTx = { to, value, gas, nonce, chainId, data: "0x" as const, type: txType };
  let signed;
  if (txType === "eip1559") {
    const maxFeePerGas = argString(args, "max-fee-per-gas-wei");
    const maxPriorityFeePerGas = argString(args, "max-priority-fee-per-gas-wei");
    if (!maxFeePerGas || !maxPriorityFeePerGas) {
      throw new Error("EIP-1559 mode requires --max-fee-per-gas-wei and --max-priority-fee-per-gas-wei");
    }
    signed = await signRawTransaction({
      ...baseTx,
      maxFeePerGas: BigInt(maxFeePerGas),
      maxPriorityFeePerGas: BigInt(maxPriorityFeePerGas),
    });
  } else {
    const gasPrice = argString(args, "gas-price-wei");
    const resolvedGasPrice = gasPrice ? BigInt(gasPrice) : await publicClient.getGasPrice();
    signed = await signRawTransaction({
      ...baseTx,
      gasPrice: resolvedGasPrice,
    });
  }

  const sent = await sendSignedTransaction(signed.serializedTransaction, wait);
  console.log(
    JSON.stringify(
      {
        status: "ok",
        from,
        to,
        value: value.toString(),
        signHash: signed.hash,
        ...sent,
      },
      null,
      2
    )
  );
}

main().catch((err) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(`send-native.ts error: ${message}`);
  process.exit(1);
});
