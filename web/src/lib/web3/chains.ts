"use client";

import { defineChain } from "viem";

const fallbackRpcUrl = "https://monad-mainnet.drpc.org";
const fallbackExplorerUrl = "https://monadexplorer.com";

export const monadMainnet = defineChain({
  id: 143,
  name: "Monad",
  nativeCurrency: {
    name: "MON",
    symbol: "MON",
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? fallbackRpcUrl],
    },
    public: {
      http: [process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? fallbackRpcUrl],
    },
  },
  blockExplorers: {
    default: {
      name: "Monad Explorer",
      url: process.env.NEXT_PUBLIC_MONAD_EXPLORER_URL ?? fallbackExplorerUrl,
    },
  },
});
