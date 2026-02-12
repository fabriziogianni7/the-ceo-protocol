"use client";

import { useMemo } from "react";
import { useAccount, useReadContract, useReadContracts } from "wagmi";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { erc20Abi } from "@/lib/contracts/abi/erc20Abi";
import { contractAddresses } from "@/lib/web3/addresses";

export function useVaultSnapshot() {
  const { address } = useAccount();

  const reads = useReadContracts({
    contracts: [
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "totalAssets" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "totalSupply" },
      {
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "balanceOf",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_currentEpoch" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_epochStartTime" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_epochDuration" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_ceoGracePeriod" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_epochExecuted" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_pendingPerformanceFeeUsdc" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_minDeposit" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_minWithdraw" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_vaultCap" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_maxDepositPerAddress" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "getTopAgent" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "getSecondAgent" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "isVotingOpen" },
      {
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "maxDeposit",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      {
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "maxRedeem",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      {
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "maxWithdraw",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      {
        address: contractAddresses.usdc,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      {
        address: contractAddresses.usdc,
        abi: erc20Abi,
        functionName: "allowance",
        args: [address ?? "0x0000000000000000000000000000000000000000", contractAddresses.ceoVault],
      },
      {
        address: contractAddresses.ceoToken,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      {
        address: contractAddresses.ceoToken,
        abi: erc20Abi,
        functionName: "allowance",
        args: [address ?? "0x0000000000000000000000000000000000000000", contractAddresses.ceoVault],
      },
      {
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "getClaimableFees",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      {
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "getAgentInfo",
        args: [address ?? "0x0000000000000000000000000000000000000000"],
      },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "getAgentList" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "getLeaderboard" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "getProposalCount", args: [BigInt(1)] },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "s_owner" },
      { address: contractAddresses.ceoVault, abi: ceoVaultAbi, functionName: "paused" },
    ],
    query: { refetchInterval: 12_000 },
  });

  return useMemo(() => ({ ...reads, address }), [reads, address]);
}

export function useProposal(epoch: bigint, proposalId: bigint) {
  return useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getProposal",
    args: [epoch, proposalId],
    query: { enabled: epoch > BigInt(0) },
  });
}

export function useProposalCount(epoch: bigint) {
  return useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getProposalCount",
    args: [epoch],
    query: { enabled: epoch > BigInt(0) },
  });
}
