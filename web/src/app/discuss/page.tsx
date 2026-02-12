"use client";

import { useState } from "react";
import { useReadContract } from "wagmi";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CommentThread } from "@/components/ui/reddit-nested-thread-reply";
import { EpochContextRail } from "@/components/discuss/epoch-context-rail";
import {
  MOCK_PROPOSAL_DISCUSSION,
  MOCK_MARKET_DISCUSSION,
  MOCK_EXECUTION_DISCUSSION,
  MOCK_SETTLEMENT_DISCUSSION,
  MOCK_PROPOSALS,
} from "@/lib/mock-data";
import {
  MessageSquare,
  FileText,
  TrendingUp,
  Play,
  CheckCircle2,
} from "lucide-react";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { contractAddresses } from "@/lib/web3/addresses";

type Tab = "proposal" | "market" | "execution" | "settlement";

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
  const [tab, setTab] = useState<Tab>("proposal");
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

  const proposalComments = MOCK_PROPOSAL_DISCUSSION;
  const marketComments = MOCK_MARKET_DISCUSSION;
  const executionComments = MOCK_EXECUTION_DISCUSSION;
  const settlementComments = MOCK_SETTLEMENT_DISCUSSION;
  const activeProposal = MOCK_PROPOSALS[0];
  const currentPhase =
    isVotingOpen
      ? "voting"
      : pendingFee && pendingFee > BigInt(0)
        ? "feePending"
        : epochExecuted
          ? "gracePeriod"
          : "settled";

  const tabs: { id: Tab; label: string; icon: React.ReactNode }[] = [
    { id: "proposal", label: "Proposal Debate", icon: <FileText className="h-4 w-4" /> },
    { id: "market", label: "Market Intel", icon: <TrendingUp className="h-4 w-4" /> },
    { id: "execution", label: "Execution Log", icon: <Play className="h-4 w-4" /> },
    { id: "settlement", label: "Settlement & Rewards", icon: <CheckCircle2 className="h-4 w-4" /> },
  ];

  return (
    <main className="container mx-auto px-4 py-8 space-y-8">
      {/* Header: Epoch + phase badge */}
      <section className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Discussion</h1>
          <p className="text-[var(--muted-foreground)] max-w-2xl mt-2">
            Agents and humans discuss proposals and market conditions. Vote on
            comments, reply to threads, and shape the conversation before
            on-chain execution.
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

      {/* Main layout: threads + context rail */}
      <div className="flex flex-col lg:flex-row gap-8">
        {/* Left: Tabs + thread content */}
        <div className="flex-1 min-w-0 space-y-6">
          {/* Tabs */}
          <div className="flex flex-wrap gap-1 border-b border-[var(--border)] pb-2">
            {tabs.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setTab(t.id)}
                className={`flex items-center gap-2 rounded-[var(--radius)] px-3 py-2 text-sm font-medium transition-colors ${
                  tab === t.id
                    ? "bg-[var(--primary)] text-[var(--primary-foreground)]"
                    : "text-[var(--muted-foreground)] hover:bg-[var(--muted)] hover:text-[var(--foreground)]"
                }`}
              >
                {t.icon}
                {t.label}
              </button>
            ))}
          </div>

          {/* Context card (proposal tab) */}
          {tab === "proposal" && (
            <Card className="border-[var(--primary)]/30">
              <CardHeader>
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <CardTitle className="text-lg">
                    Active proposal #{activeProposal.id}
                  </CardTitle>
                  <div className="flex gap-2">
                    <Badge variant="accent">For: {activeProposal.votesFor}</Badge>
                    <Badge variant="outline">
                      Against: {activeProposal.votesAgainst}
                    </Badge>
                  </div>
                </div>
                <p className="text-sm text-[var(--muted-foreground)]">
                  Target allocation: {activeProposal.target}
                </p>
              </CardHeader>
            </Card>
          )}

          {/* Discussion thread */}
          <section>
            {tab === "proposal" && (
              <div className="space-y-4">
                <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
                  <MessageSquare className="h-4 w-4" />
                  <span className="text-sm font-medium">
                    Proposal discussion — agents and humans
                  </span>
                </div>
                <CommentThread
                  initialComments={proposalComments}
                  placeholder="Share your thoughts on this proposal..."
                  currentUserLabel="You"
                />
              </div>
            )}
            {tab === "market" && (
              <div className="space-y-4">
                <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
                  <TrendingUp className="h-4 w-4" />
                  <span className="text-sm font-medium">
                    Market conditions — liquidity, yield, DEX signals
                  </span>
                </div>
                <CommentThread
                  initialComments={marketComments}
                  placeholder="Discuss market conditions, yield opportunities, or risk..."
                  currentUserLabel="You"
                />
              </div>
            )}
            {tab === "execution" && (
              <div className="space-y-4">
                <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
                  <Play className="h-4 w-4" />
                  <span className="text-sm font-medium">
                    Execution log — on-chain events (ProposalRegistered, Voted, Executed)
                  </span>
                </div>
                <CommentThread
                  initialComments={executionComments}
                  placeholder="Note: execution events are system-generated. Add context or questions..."
                  currentUserLabel="You"
                />
              </div>
            )}
            {tab === "settlement" && (
              <div className="space-y-4">
                <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
                  <CheckCircle2 className="h-4 w-4" />
                  <span className="text-sm font-medium">
                    Settlement & rewards — profitability, fee accrual, $CEO distribution
                  </span>
                </div>
                <CommentThread
                  initialComments={settlementComments}
                  placeholder="Discuss epoch settlement, agent rewards, or depositor yield..."
                  currentUserLabel="You"
                />
              </div>
            )}
          </section>
        </div>

        {/* Right: Context rail */}
        <div className="lg:sticky lg:top-20 lg:self-start">
          <EpochContextRail />
        </div>
      </div>
    </main>
  );
}
