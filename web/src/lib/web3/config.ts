"use client";

import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { monadMainnet } from "@/lib/web3/chains";

export const wagmiConfig = createConfig({
  chains: [monadMainnet],
  connectors: [injected()],
  transports: {
    [monadMainnet.id]: http(
      process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? monadMainnet.rpcUrls.default.http[0]
    ),
  },
});
