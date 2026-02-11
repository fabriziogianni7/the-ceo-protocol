"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  MOCK_EPOCH_STATE,
  MOCK_CEO,
  MOCK_SECOND_AGENT,
  MOCK_LEADERBOARD,
  MOCK_PROPOSALS,
} from "@/lib/mock-data";
import { Clock, Crown, Award, FileText, Zap } from "lucide-react";

function formatCountdown(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
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

function getPhaseVariant(phase: string): "default" | "accent" | "secondary" | "destructive" | "outline" {
  switch (phase) {
    case "voting":
      return "accent";
    case "gracePeriod":
      return "default";
    case "fallback":
      return "secondary";
    case "feePending":
      return "destructive";
    default:
      return "outline";
  }
}

export function EpochContextRail() {
  const { epoch, phase, epochStartTime, epochDuration, ceoGracePeriod } =
    MOCK_EPOCH_STATE;
  const now = Math.floor(Date.now() / 1000);
  const votingEnd = epochStartTime + epochDuration;
  const graceEnd = votingEnd + ceoGracePeriod;
  const remaining =
    phase === "voting"
      ? Math.max(0, votingEnd - now)
      : phase === "gracePeriod"
        ? Math.max(0, graceEnd - now)
        : 0;

  const winningProposal = MOCK_PROPOSALS[0];

  return (
    <aside className="w-full lg:w-80 shrink-0 space-y-4">
      {/* Epoch & phase */}
      <Card>
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <CardTitle className="text-base">Epoch {epoch}</CardTitle>
            <Badge variant={getPhaseVariant(phase)} className="text-xs">
              {getPhaseLabel(phase)}
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-2">
          {phase === "voting" && remaining > 0 && (
            <div className="flex items-center gap-2 text-sm text-[var(--muted-foreground)]">
              <Clock className="h-4 w-4" />
              <span>Voting ends in {formatCountdown(remaining)}</span>
            </div>
          )}
          {phase === "gracePeriod" && remaining > 0 && (
            <div className="flex items-center gap-2 text-sm text-[var(--muted-foreground)]">
              <Clock className="h-4 w-4" />
              <span>Grace ends in {formatCountdown(remaining)}</span>
            </div>
          )}
        </CardContent>
      </Card>

      {/* CEO & #2 */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base flex items-center gap-2">
            <Crown className="h-4 w-4" />
            CEO & Executor
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <div>
            <span className="text-[var(--muted-foreground)]">CEO:</span>{" "}
            <span className="font-mono">{MOCK_CEO}</span>
          </div>
          <div>
            <span className="text-[var(--muted-foreground)]">#2:</span>{" "}
            <span className="font-mono">{MOCK_SECOND_AGENT}</span>
          </div>
        </CardContent>
      </Card>

      {/* Winning proposal */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base flex items-center gap-2">
            <FileText className="h-4 w-4" />
            Winning Proposal
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <div>
            <span className="text-[var(--muted-foreground)]">#0:</span>{" "}
            {winningProposal.target}
          </div>
          <div className="flex gap-2">
            <Badge variant="accent">For: {winningProposal.votesFor}</Badge>
            <Badge variant="outline">Against: {winningProposal.votesAgainst}</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Leaderboard */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base flex items-center gap-2">
            <Award className="h-4 w-4" />
            Leaderboard
          </CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-1.5 text-sm">
            {MOCK_LEADERBOARD.slice(0, 5).map((a, i) => (
              <li
                key={a.address}
                className="flex justify-between items-center"
              >
                <span className="font-mono truncate max-w-[140px]">
                  {a.isCEO ? "👑 " : ""}
                  {a.address}
                </span>
                <Badge variant={a.isCEO ? "accent" : "outline"} className="text-xs">
                  {a.score}
                </Badge>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      {/* Fee state */}
      {MOCK_EPOCH_STATE.pendingPerformanceFeeUsdc !== "0" && (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base flex items-center gap-2">
              <Zap className="h-4 w-4" />
              Pending Fee
            </CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="text-[var(--muted-foreground)]">
              {Number(MOCK_EPOCH_STATE.pendingPerformanceFeeUsdc) / 1e6} USDC
              awaiting conversion to $CEO for top 10 agents.
            </p>
          </CardContent>
        </Card>
      )}
    </aside>
  );
}
