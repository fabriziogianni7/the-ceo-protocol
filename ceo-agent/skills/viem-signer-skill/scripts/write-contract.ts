#!/usr/bin/env node
import { encodeFunctionData, getAddress } from "viem";
import {
  argString,
  parseArgs,
  parseArgsJson,
  parseValue,
  readAbiFromFile,
  requireArg,
  resolvePublicClient,
  sendSignedTransaction,
  signRawTransaction,
  signerAddress,
} from "./common.js";

function withGasBuffer(estimate: bigint, percent: number): bigint {
  if (percent < 0) throw new Error("gas-buffer-percent must be >= 0");
  return estimate + (estimate * BigInt(percent)) / 100n;
}

async function main() {
  const args = parseArgs(process.argv);
  const to = getAddress(requireArg(args, "to"));
  const abiFile = requireArg(args, "abi-file");
  const fn = requireArg(args, "function");
  const fnArgs = parseArgsJson(argString(args, "args-json"));
  const wait = Boolean(args.wait);
  const value = parseValue(args);
  const gasBufferPercentRaw = argString(args, "gas-buffer-percent");
  const gasBufferPercent = gasBufferPercentRaw ? Number(gasBufferPercentRaw) : 20;
  if (!Number.isFinite(gasBufferPercent) || gasBufferPercent < 0) {
    throw new Error("Invalid --gas-buffer-percent. Use a non-negative number (e.g. 20).");
  }

  const abi = await readAbiFromFile(abiFile);
  const data = encodeFunctionData({
    abi: abi as any,
    functionName: fn as any,
    args: fnArgs as any,
  });

  const { publicClient, chainId } = resolvePublicClient(args);
  const from = await signerAddress();
  const nonce = await publicClient.getTransactionCount({ address: from, blockTag: "pending" });
  const estimatedGas = await publicClient.estimateGas({
    account: from,
    to,
    data,
    value,
  });
  const gas =
    argString(args, "gas") !== undefined
      ? BigInt(requireArg(args, "gas"))
      : withGasBuffer(estimatedGas, gasBufferPercent);

  const txType = (argString(args, "type") ?? "legacy") as "legacy" | "eip1559";
  const baseTx = { to, data, value, gas, nonce, chainId, type: txType };
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
        functionName: fn,
        estimatedGas: estimatedGas.toString(),
        gasLimit: gas.toString(),
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
  console.error(`write-contract.ts error: ${message}`);
  process.exit(1);
});
