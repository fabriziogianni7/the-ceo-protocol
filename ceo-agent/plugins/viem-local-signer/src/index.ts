import {
  createPublicClient,
  createWalletClient,
  defineChain,
  getAddress,
  http,
  keccak256,
  type Hex,
  type TransactionReceipt,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

export type PreparedTx = {
  to: `0x${string}`;
  data?: Hex;
  value?: bigint;
  gas: bigint;
  nonce: number;
  chainId: number;
  type?: "legacy" | "eip1559";
  gasPrice?: bigint;
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
};

export type PluginConfig = {
  rpcUrl?: string;
  chainId?: number;
  privateKey?: Hex;
  expectedAddress?: string;
};

type RequiredEnvName = "MONAD_RPC_URL" | "AGENT_PRIVATE_KEY";

function _requiredEnv(name: RequiredEnvName): string {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value.trim();
}

function _resolveChainId(config?: PluginConfig): number {
  const fromConfig = config?.chainId;
  if (typeof fromConfig === "number" && Number.isFinite(fromConfig)) {
    return fromConfig;
  }
  return Number(process.env.MONAD_CHAIN_ID ?? "143");
}

export function createLocalViemSigner(config?: PluginConfig) {
  const rpcUrl = config?.rpcUrl ?? _requiredEnv("MONAD_RPC_URL");
  const privateKey = (config?.privateKey ?? _requiredEnv("AGENT_PRIVATE_KEY")) as Hex;
  const expectedAddress = config?.expectedAddress ?? process.env.AGENT_ADDRESS?.trim();
  const chainId = _resolveChainId(config);

  const chain = defineChain({
    id: chainId,
    name: `Monad-${chainId}`,
    nativeCurrency: { name: "MON", symbol: "MON", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  });

  const account = privateKeyToAccount(privateKey);

  if (expectedAddress && getAddress(expectedAddress) !== account.address) {
    throw new Error("AGENT_ADDRESS does not match AGENT_PRIVATE_KEY");
  }

  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ chain, transport });
  const walletClient = createWalletClient({ chain, transport, account });

  async function signPreparedTransaction(
    input: PreparedTx
  ): Promise<{ serializedTransaction: Hex; hash: Hex }> {
    const baseTx = {
      account,
      to: getAddress(input.to),
      data: input.data ?? "0x",
      value: input.value ?? 0n,
      gas: input.gas,
      nonce: input.nonce,
      chainId: input.chainId,
    };

    let serializedTransaction: Hex;
    const wantsEip1559 = input.type === "eip1559";

    if (wantsEip1559) {
      if (typeof input.maxFeePerGas !== "bigint" || typeof input.maxPriorityFeePerGas !== "bigint") {
        throw new Error("EIP-1559 transaction requires maxFeePerGas and maxPriorityFeePerGas");
      }

      serializedTransaction = await walletClient.signTransaction({
        ...baseTx,
        maxFeePerGas: input.maxFeePerGas,
        maxPriorityFeePerGas: input.maxPriorityFeePerGas,
      });
    } else {
      if (typeof input.gasPrice !== "bigint") {
        throw new Error("Legacy transaction requires gasPrice");
      }
      serializedTransaction = await walletClient.signTransaction({
        ...baseTx,
        gasPrice: input.gasPrice,
        type: "legacy",
      });
    }

    return {
      serializedTransaction,
      hash: keccak256(serializedTransaction),
    };
  }

  async function sendSignedTransaction(serializedTransaction: Hex): Promise<Hex> {
    return publicClient.sendRawTransaction({ serializedTransaction });
  }

  async function waitFor(hash: Hex): Promise<TransactionReceipt> {
    return publicClient.waitForTransactionReceipt({ hash });
  }

  return {
    chainId,
    account: account.address,
    publicClient,
    walletClient,
    signPreparedTransaction,
    sendSignedTransaction,
    waitFor,
  };
}
