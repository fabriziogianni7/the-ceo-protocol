import type { Address, Hex } from "viem";

export interface VaultAction {
  target: Address;
  value: bigint;
  data: Hex;
}

export interface AgentInfo {
  active: boolean;
  ceoStaked: bigint;
  score: bigint;
  erc8004Id: bigint;
  metadataURI: string;
  registeredAt: bigint;
}

export interface ProposalInfo {
  proposalHash: Hex;
  proposalURI: string;
  proposer: Address;
  votesFor: bigint;
  votesAgainst: bigint;
  epoch: bigint;
  executed: boolean;
  settled: boolean;
}
