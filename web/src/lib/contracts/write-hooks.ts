"use client";

import { useWriteContract } from "wagmi";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { erc20Abi } from "@/lib/contracts/abi/erc20Abi";
import { contractAddresses } from "@/lib/web3/addresses";
import type { VaultAction } from "@/lib/contracts/types";

export function useCeoVaultWrites() {
  const write = useWriteContract();

  return {
    ...write,
    deposit: (assets: bigint, receiver: `0x${string}`) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "deposit",
        args: [assets, receiver],
      }),
    mint: (shares: bigint, receiver: `0x${string}`) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "mint",
        args: [shares, receiver],
      }),
    withdraw: (assets: bigint, receiver: `0x${string}`, owner: `0x${string}`) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "withdraw",
        args: [assets, receiver, owner],
      }),
    redeem: (shares: bigint, receiver: `0x${string}`, owner: `0x${string}`) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "redeem",
        args: [shares, receiver, owner],
      }),
    registerAgent: (metadataURI: string, ceoAmount: bigint, erc8004Id: bigint) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "registerAgent",
        args: [metadataURI, ceoAmount, erc8004Id],
      }),
    deregisterAgent: () =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "deregisterAgent",
        args: [],
      }),
    registerProposal: (actions: VaultAction[], proposalURI: string) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "registerProposal",
        args: [actions, proposalURI],
      }),
    vote: (proposalId: bigint, support: boolean) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "vote",
        args: [proposalId, support],
      }),
    execute: (proposalId: bigint, actions: VaultAction[]) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "execute",
        args: [proposalId, actions],
      }),
    convertPerformanceFee: (actions: VaultAction[], minCeoOut: bigint) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "convertPerformanceFee",
        args: [actions, minCeoOut],
      }),
    settleEpoch: () =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "settleEpoch",
        args: [],
      }),
    withdrawFees: () =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "withdrawFees",
        args: [],
      }),
  };
}

export function useTokenWrites() {
  const write = useWriteContract();

  return {
    ...write,
    approveUsdc: (spender: `0x${string}`, amount: bigint) =>
      write.writeContractAsync({
        address: contractAddresses.usdc,
        abi: erc20Abi,
        functionName: "approve",
        args: [spender, amount],
      }),
    approveCeo: (spender: `0x${string}`, amount: bigint) =>
      write.writeContractAsync({
        address: contractAddresses.ceoToken,
        abi: erc20Abi,
        functionName: "approve",
        args: [spender, amount],
      }),
    transferShares: (to: `0x${string}`, amount: bigint) =>
      write.writeContractAsync({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "transfer",
        args: [to, amount],
      }),
  };
}
