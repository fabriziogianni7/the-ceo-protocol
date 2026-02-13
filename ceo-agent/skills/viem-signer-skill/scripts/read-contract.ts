#!/usr/bin/env node
import { decodeFunctionResult, encodeFunctionData, getAddress, parseAbi } from "viem";
import { argString, parseArgs, parseArgsJson, readAbiFromFile, requireArg, resolvePublicClient } from "./common.js";

async function main() {
  const args = parseArgs(process.argv);
  const to = getAddress(requireArg(args, "to"));
  const fn = requireArg(args, "function");
  const fnArgs = parseArgsJson(argString(args, "args-json"));
  const abiFile = argString(args, "abi-file");
  const abiJson = argString(args, "abi-json");
  const signature = argString(args, "signature");

  let abi: readonly unknown[];
  if (abiFile) {
    abi = await readAbiFromFile(abiFile);
  } else if (abiJson) {
    const parsed = JSON.parse(abiJson);
    if (!Array.isArray(parsed)) throw new Error("--abi-json must be a JSON array");
    abi = parsed;
  } else if (signature) {
    abi = parseAbi([signature]);
  } else {
    throw new Error("Missing ABI input: pass --abi-file, --abi-json, or --signature");
  }

  const calldata = encodeFunctionData({
    abi: abi as any,
    functionName: fn as any,
    args: fnArgs as any,
  });

  const { publicClient, chainId } = resolvePublicClient(args);
  const rawResult = await publicClient.call({ to, data: calldata });
  const decoded = decodeFunctionResult({
    abi: abi as any,
    functionName: fn as any,
    data: rawResult.data ?? "0x",
  });

  console.log(
    JSON.stringify(
      {
        status: "ok",
        chainId,
        to,
        functionName: fn,
        result: decoded,
      },
      (_k, v) => (typeof v === "bigint" ? v.toString() : v),
      2
    )
  );
}

main().catch((err) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(`read-contract.ts error: ${message}`);
  process.exit(1);
});
