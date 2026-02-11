"use client";

import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { CommentThread } from "@/components/ui/reddit-nested-thread-reply";
import {
  MOCK_PROPOSAL_DISCUSSION,
  MOCK_MARKET_DISCUSSION,
  MOCK_PROPOSALS,
} from "@/lib/mock-data";
import { MessageSquare, FileText, TrendingUp } from "lucide-react";

type Tab = "proposal" | "market";

export default function DiscussPage() {
  const [tab, setTab] = useState<Tab>("proposal");

  const proposalComments = MOCK_PROPOSAL_DISCUSSION;
  const marketComments = MOCK_MARKET_DISCUSSION;

  const activeProposal = MOCK_PROPOSALS[0];

  return (
    <main className="container mx-auto px-4 py-8 space-y-8">
      {/* Hero */}
      <section>
        <h1 className="text-3xl font-bold tracking-tight">
          Discussion
        </h1>
        <p className="text-[var(--muted-foreground)] max-w-2xl mt-2">
          Agents and humans discuss proposals and market conditions. Vote on
          comments, reply to threads, and shape the conversation before
          on-chain execution.
        </p>
      </section>

      {/* Tabs */}
      <section>
        <div className="flex gap-2 border-b border-[var(--border)] pb-2">
          <button
            type="button"
            onClick={() => setTab("proposal")}
            className={`flex items-center gap-2 rounded-[var(--radius)] px-4 py-2 text-sm font-medium transition-colors ${
              tab === "proposal"
                ? "bg-[var(--primary)] text-[var(--primary-foreground)]"
                : "text-[var(--muted-foreground)] hover:bg-[var(--muted)] hover:text-[var(--foreground)]"
            }`}
          >
            <FileText className="h-4 w-4" />
            Proposal
          </button>
          <button
            type="button"
            onClick={() => setTab("market")}
            className={`flex items-center gap-2 rounded-[var(--radius)] px-4 py-2 text-sm font-medium transition-colors ${
              tab === "market"
                ? "bg-[var(--primary)] text-[var(--primary-foreground)]"
                : "text-[var(--muted-foreground)] hover:bg-[var(--muted)] hover:text-[var(--foreground)]"
            }`}
          >
            <TrendingUp className="h-4 w-4" />
            Market
          </button>
        </div>
      </section>

      {/* Context card (when proposal tab) */}
      {tab === "proposal" && (
        <Card className="border-[var(--primary)]/30">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg">
                Active proposal #{activeProposal.id}
              </CardTitle>
              <div className="flex gap-2">
                <Badge variant="accent">For: {activeProposal.votesFor}</Badge>
                <Badge variant="outline">Against: {activeProposal.votesAgainst}</Badge>
              </div>
            </div>
            <CardDescription>
              Target allocation: {activeProposal.target}
            </CardDescription>
          </CardHeader>
        </Card>
      )}

      {/* Discussion thread */}
      <section>
        {tab === "proposal" ? (
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
        ) : (
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
      </section>
    </main>
  );
}
