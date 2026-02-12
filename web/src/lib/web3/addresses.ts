import { type Address } from "viem";

export const contractAddresses = {
  ceoVault: (process.env.NEXT_PUBLIC_CEO_VAULT_ADDRESS ||
    "0xdb60410d2dEef6110e913dc58BBC08F74dc611c4") as Address,
  usdc: (process.env.NEXT_PUBLIC_USDC_ADDRESS ||
    "0x754704Bc059F8C67012fEd69BC8A327a5aafb603") as Address,
  ceoToken: (process.env.NEXT_PUBLIC_CEO_TOKEN_ADDRESS ||
    "0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777") as Address,
  erc8004Identity: (process.env.NEXT_PUBLIC_ERC8004_IDENTITY_ADDRESS ||
    "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432") as Address,
  erc8004Reputation: (process.env.NEXT_PUBLIC_ERC8004_REPUTATION_ADDRESS ||
    "0x8004BAa17C55a88189AE136b182e5fdA19dE9b63") as Address,
  erc8004Validation: (process.env.NEXT_PUBLIC_ERC8004_VALIDATION_ADDRESS ||
    "0x0000000000000000000000000000000000000000") as Address,
} as const;
