import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile } from "node:fs/promises";
import {
  createPublicClient,
  defineChain,
  getAddress,
  http,
  parseEther,
  type Address,
  type Hex,
} from "viem";

const pexecFile = promisify(execFile);

export type ArgsMap = Record<string, string | boolean>;

export function parseArgs(argv: string[]): ArgsMap {
  const args: ArgsMap = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

export function argString(args: ArgsMap, key: string): string | undefined {
  const value = args[key];
  return typeof value === "string" ? value : undefined;
}

export function requireArg(args: ArgsMap, key: string): string {
  const value = argString(args, key);
  if (!value) throw new Error(`Missing required --${key}`);
  return value;
}

export function env(name: string): string {
  const value = process.env[name];
  if (!value || value.trim() === "") throw new Error(`Missing required env var: ${name}`);
  return value.trim();
}

export function resolvePublicClient(args: ArgsMap) {
  const chainId = Number(argString(args, "chainId") ?? process.env.MONAD_CHAIN_ID ?? "143");
  const rpcUrl = argString(args, "rpcUrl") ?? process.env.MONAD_RPC_URL;
  if (!rpcUrl) throw new Error("Missing RPC URL. Pass --rpcUrl or set MONAD_RPC_URL.");
  const chain = defineChain({
    id: chainId,
    name: `Monad-${chainId}`,
    nativeCurrency: { name: "MON", symbol: "MON", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  });
  const publicClient = createPublicClient({ chain, transport: http(rpcUrl) });
  return { chainId, rpcUrl, publicClient };
}

export async function signerAddress(): Promise<Address> {
  const { stdout } = await pexecFile("viem-local-signer", ["address"]);
  return getAddress(stdout.trim());
}

type RawTxInput = {
  to: Address;
  data?: Hex;
  value?: bigint;
  gas: bigint;
  nonce: number;
  chainId: number;
  gasPrice?: bigint;
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
  type?: "legacy" | "eip1559";
};

function rawTxToJson(tx: RawTxInput): string {
  const normalized = {
    ...tx,
    data: tx.data ?? "0x",
    value: (tx.value ?? 0n).toString(),
    gas: tx.gas.toString(),
    nonce: tx.nonce,
    chainId: tx.chainId,
    gasPrice: tx.gasPrice?.toString(),
    maxFeePerGas: tx.maxFeePerGas?.toString(),
    maxPriorityFeePerGas: tx.maxPriorityFeePerGas?.toString(),
  };
  return JSON.stringify(normalized);
}

export async function signRawTransaction(tx: RawTxInput): Promise<{ hash: Hex; serializedTransaction: Hex }> {
  const { stdout } = await pexecFile("viem-local-signer", ["sign-raw", "--tx-json", rawTxToJson(tx)]);
  return JSON.parse(stdout);
}

export async function sendSignedTransaction(serializedTx: Hex, wait: boolean) {
  const args = ["send-signed", "--signed-tx", serializedTx];
  if (wait) args.push("--wait");
  const { stdout } = await pexecFile("viem-local-signer", args);
  return JSON.parse(stdout);
}

export async function readAbiFromFile(path: string): Promise<readonly unknown[]> {
  const raw = await readFile(path, "utf-8");
  const trimmed = raw.trim();
  if (trimmed.startsWith("export ")) {
    throw new Error(
      `ABI file at ${path} looks like TypeScript/JavaScript export syntax. ` +
        "Use a pure JSON ABI file (array), or pass --signature / --abi-json."
    );
  }
  return JSON.parse(trimmed);
}

export function parseArgsJson(raw?: string): readonly unknown[] {
  if (!raw) return [];
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed)) throw new Error("--args-json must be a JSON array");
  return parsed;
}

export function parseValue(args: ArgsMap): bigint {
  const valueWei = argString(args, "value-wei");
  const valueEth = argString(args, "value-eth");
  if (valueWei && valueEth) throw new Error("Pass only one value unit: --value-wei or --value-eth");
  if (valueWei) return BigInt(valueWei);
  if (valueEth) return parseEther(valueEth);
  return 0n;
}
