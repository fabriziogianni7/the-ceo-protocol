"use client";

import { useEffect, useState } from "react";
import { useBlockNumber, usePublicClient } from "wagmi";
import { contractAddresses } from "@/lib/web3/addresses";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import type { CommentType } from "@/components/ui/reddit-nested-thread-reply";

const EVENTS_BLOCK_RANGE = 100_000n;
const MAX_EVENTS = 50;

function shortenAddr(addr: string): string {
  if (!addr || addr.length < 12) return addr;
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function eventToComment(
  event: { eventName: string; args?: Record<string, unknown>; transactionHash?: string; blockNumber?: bigint }
): CommentType {
  const txShort = event.transactionHash
    ? `${event.transactionHash.slice(0, 10)}...`
    : "";
  const blockNum = event.blockNumber?.toString() ?? "";

  let content = "";
  let eventType: CommentType["eventType"] = "proposal";

  const args = event.args ?? {};
  switch (event.eventName) {
    case "ProposalRegistered":
      content = `Proposal #${(args.proposalId as bigint)?.toString() ?? "?"} registered by ${shortenAddr((args.proposer as string) ?? "")}. Hash: ${txShort}`;
      eventType = "proposal";
      break;
    case "Voted":
      content = `${shortenAddr((args.voter as string) ?? "")} voted ${(args.support as boolean) ? "FOR" : "AGAINST"} proposal #${(args.proposalId as bigint)?.toString() ?? "?"} (weight: ${(args.weight as bigint)?.toString() ?? "?"}).`;
      eventType = "voted";
      break;
    case "Executed":
      content = `Proposal #${(args.proposalId as bigint)?.toString() ?? "?"} executed by CEO ${shortenAddr((args.ceo as string) ?? "")}.`;
      eventType = "executed";
      break;
    case "EpochSettled":
      content = `Epoch ${(args.epoch as bigint)?.toString() ?? "?"} settled. Profitable: ${(args.profitable as boolean) ? "yes" : "no"}. Revenue: ${(args.revenue as bigint)?.toString() ?? "0"}.`;
      eventType = "settled";
      break;
    case "PerformanceFeeAccrued":
      content = `Performance fee accrued: ${(args.usdcAmount as bigint)?.toString() ?? "0"} USDC (epoch ${(args.epoch as bigint)?.toString() ?? "?"}).`;
      eventType = "feeAccrued";
      break;
    case "PerformanceFeeConverted":
      content = `Performance fee converted to $CEO by ${shortenAddr((args.executor as string) ?? "")}.`;
      eventType = "feeConverted";
      break;
    default:
      content = `${event.eventName} at block ${blockNum}`;
  }

  return {
    id: `evt-${event.transactionHash ?? ""}-${event.blockNumber ?? ""}`,
    author: "System",
    content,
    timestamp: blockNum ? `#${blockNum}` : "on-chain",
    upvotes: 0,
    downvotes: 0,
    replies: [],
    isSystem: true,
    eventType,
    onchainRef: event.transactionHash,
  };
}

export function useVaultEvents(): CommentType[] {
  const publicClient = usePublicClient();
  const { data: blockNumber } = useBlockNumber();
  const [events, setEvents] = useState<CommentType[]>([]);

  useEffect(() => {
    if (!publicClient || blockNumber === undefined) return;

    const fromBlock = blockNumber > EVENTS_BLOCK_RANGE ? blockNumber - EVENTS_BLOCK_RANGE : 0n;

    publicClient
      .getContractEvents({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        fromBlock,
        toBlock: "latest",
      })
      .then((logs) => {
        const relevant = logs
          .filter(
            (l) =>
              l.eventName === "ProposalRegistered" ||
              l.eventName === "Voted" ||
              l.eventName === "Executed" ||
              l.eventName === "EpochSettled" ||
              l.eventName === "PerformanceFeeAccrued" ||
              l.eventName === "PerformanceFeeConverted"
          )
          .slice(-MAX_EVENTS)
          .reverse();
        setEvents(relevant.map((l) => eventToComment(l)));
      })
      .catch(() => setEvents([]));
  }, [publicClient, blockNumber]);

  return events;
}
