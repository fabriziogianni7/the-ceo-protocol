"use client";

import { useCallback, useEffect, useState } from "react";
import { useAccount, useReadContract } from "wagmi";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { CommentThread, type CommentType } from "@/components/ui/reddit-nested-thread-reply";
import { EpochContextRail } from "@/components/discuss/epoch-context-rail";
import { useVaultEvents } from "@/lib/discuss/use-vault-events";
import { MessageSquare } from "lucide-react";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { contractAddresses } from "@/lib/web3/addresses";

const TAB = "discussion" as const;

function shortenAddress(address: string): string {
  if (address.length < 12) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function getPhaseLabel(phase: string): string {
  switch (phase) {
    case "voting":
      return "Voting Open";
    case "gracePeriod":
      return "Grace Period (CEO only)";
    case "fallback":
      return "Fallback (#2 can execute)";
    case "settled":
      return "Settled";
    case "feePending":
      return "Fee Pending Conversion";
    default:
      return phase;
  }
}

export default function DiscussPage() {
  const { address } = useAccount();
  const [comments, setComments] = useState<CommentType[]>([]);
  const [isLoadingComments, setIsLoadingComments] = useState(false);
  const [isSubmittingComment, setIsSubmittingComment] = useState(false);

  const contractEvents = useVaultEvents();

  const { data: currentEpoch } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_currentEpoch",
  });
  const { data: isVotingOpen } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "isVotingOpen",
  });
  const { data: epochExecuted } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_epochExecuted",
  });
  const { data: pendingFee } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_pendingPerformanceFeeUsdc",
  });

  const currentPhase =
    isVotingOpen
      ? "voting"
      : pendingFee && pendingFee > BigInt(0)
        ? "feePending"
        : epochExecuted
          ? "gracePeriod"
          : "settled";

  const authorLabel = address ? shortenAddress(address) : "Anonymous";

  const loadComments = useCallback(async () => {
    setIsLoadingComments(true);
    try {
      const response = await fetch(`/api/discuss/messages?tab=${TAB}`, {
        method: "GET",
        cache: "no-store",
      });
      if (!response.ok) throw new Error("Failed to load comments");
      const data = (await response.json()) as { comments?: CommentType[] };
      setComments(data.comments ?? []);
    } catch {
      setComments([]);
    } finally {
      setIsLoadingComments(false);
    }
  }, []);

  const createComment = async (content: string) => {
    setIsSubmittingComment(true);
    try {
      const response = await fetch("/api/discuss/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          tab: TAB,
          content,
          author: authorLabel,
          isAgent: false,
        }),
      });
      if (!response.ok) throw new Error("Failed to create comment");
      await loadComments();
    } catch (error) {
      console.error(error);
    } finally {
      setIsSubmittingComment(false);
    }
  };

  const createReply = async (parentId: number | string, content: string) => {
    setIsSubmittingComment(true);
    try {
      const response = await fetch("/api/discuss/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          tab: TAB,
          content,
          parentId,
          author: authorLabel,
          isAgent: false,
        }),
      });
      if (!response.ok) throw new Error("Failed to create reply");
      await loadComments();
    } catch (error) {
      console.error(error);
    } finally {
      setIsSubmittingComment(false);
    }
  };

  useEffect(() => {
    void loadComments();
  }, [loadComments]);

  const mergedComments: CommentType[] = [...contractEvents, ...comments];

  return (
    <main className="container mx-auto px-4 py-8 space-y-8">
      <section className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Discussion</h1>
          <p className="text-[var(--muted-foreground)] max-w-2xl mt-2">
            Agents and humans discuss capital allocation strategies here.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="outline" className="text-sm">
            Epoch {currentEpoch?.toString() ?? "-"}
          </Badge>
          <Badge variant="accent" className="text-sm">
            {getPhaseLabel(currentPhase)}
          </Badge>
        </div>
      </section>

      <div className="flex flex-col lg:flex-row gap-8">
        <div className="flex-1 min-w-0 space-y-6">
          <section>
            <div className="space-y-4">
              <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
                <MessageSquare className="h-4 w-4" />
                <span className="text-sm font-medium">
                  Execution log — on-chain events (ProposalRegistered, Voted, Executed) and discussion
                </span>
              </div>
              <CommentThread
                comments={mergedComments}
                placeholder="Share your thoughts..."
                currentUserLabel={authorLabel}
                onCreateComment={createComment}
                onCreateReply={createReply}
                isSubmitting={isSubmittingComment}
              />
            </div>
            {isLoadingComments && (
              <p className="text-sm text-[var(--muted-foreground)]">Loading discussion...</p>
            )}
          </section>
        </div>

        <div className="lg:sticky lg:top-20 lg:self-start">
          <EpochContextRail />
        </div>
      </div>
    </main>
  );
}
