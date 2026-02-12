"use client";

import { useEffect, useMemo, useState } from "react";
import { useReadContract } from "wagmi";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Clock, Crown, Award, FileText, Zap } from "lucide-react";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { contractAddresses } from "@/lib/web3/addresses";
import { formatAmount, shortenAddress } from "@/lib/contracts/format";

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
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  useEffect(() => {
    const id = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(id);
  }, []);

  const { data: currentEpoch } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_currentEpoch",
  });
  const { data: epochStartTime } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_epochStartTime",
  });
  const { data: epochDuration } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_epochDuration",
  });
  const { data: ceoGracePeriod } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_ceoGracePeriod",
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
  const { data: pendingPerformanceFeeUsdc } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_pendingPerformanceFeeUsdc",
  });
  const { data: topAgent } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getTopAgent",
  });
  const { data: secondAgent } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getSecondAgent",
  });
  const { data: leaderboardRaw } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getLeaderboard",
  });
  const { data: proposalCount } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getProposalCount",
    args: [currentEpoch ?? BigInt(1)],
    query: { enabled: Boolean(currentEpoch) },
  });
  const { data: winningProposalTuple } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getWinningProposal",
    args: [currentEpoch ?? BigInt(1)],
    query: {
      enabled: Boolean(currentEpoch) && proposalCount !== undefined && proposalCount > BigInt(0),
    },
  });
  const bestId = winningProposalTuple?.[0];
  const { data: winningProposalData } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getProposal",
    args: [currentEpoch ?? BigInt(1), bestId ?? BigInt(0)],
    query: {
      enabled:
        Boolean(currentEpoch) &&
        bestId !== undefined &&
        proposalCount !== undefined &&
        proposalCount > BigInt(0) &&
        bestId < proposalCount,
    },
  });

  const epoch = currentEpoch ? Number(currentEpoch) : 0;
  const phase = useMemo(() => {
    if (isVotingOpen) return "voting";
    if (pendingPerformanceFeeUsdc && pendingPerformanceFeeUsdc > BigInt(0))
      return "feePending";
    if (epochExecuted) return "gracePeriod";
    return "settled";
  }, [isVotingOpen, pendingPerformanceFeeUsdc, epochExecuted]);

  const epochStart = epochStartTime ? Number(epochStartTime) : 0;
  const duration = epochDuration ? Number(epochDuration) : 0;
  const grace = ceoGracePeriod ? Number(ceoGracePeriod) : 0;
  const votingEnd = epochStart + duration;
  const graceEnd = votingEnd + grace;
  const remaining =
    phase === "voting"
      ? Math.max(0, votingEnd - now)
      : phase === "gracePeriod"
        ? Math.max(0, graceEnd - now)
        : 0;

  const leaderboard = useMemo(() => {
    if (!leaderboardRaw?.[0] || !leaderboardRaw?.[1]) return [];
    const [agents, scores] = leaderboardRaw;
    const ceo = topAgent?.toLowerCase();
    return agents.map((addr, i) => ({
      address: shortenAddress(addr),
      rawAddress: addr,
      score: Number(scores[i] ?? BigInt(0)),
      isCEO: addr?.toLowerCase() === ceo,
    }));
  }, [leaderboardRaw, topAgent]);

  const winningProposal = winningProposalData
    ? {
        target: winningProposalData.proposalURI || `Proposal #${bestId}`,
        votesFor: Number(winningProposalData.votesFor),
        votesAgainst: Number(winningProposalData.votesAgainst),
      }
    : null;

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
            <span className="font-mono">{topAgent ? shortenAddress(topAgent) : "-"}</span>
          </div>
          <div>
            <span className="text-[var(--muted-foreground)]">#2:</span>{" "}
            <span className="font-mono">{secondAgent ? shortenAddress(secondAgent) : "-"}</span>
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
          {winningProposal ? (
            <>
              <div>
                <span className="text-[var(--muted-foreground)]">#{bestId ?? 0}:</span>{" "}
                {winningProposal.target}
              </div>
              <div className="flex gap-2">
                <Badge variant="accent">For: {winningProposal.votesFor}</Badge>
                <Badge variant="outline">Against: {winningProposal.votesAgainst}</Badge>
              </div>
            </>
          ) : (
            <p className="text-[var(--muted-foreground)] text-sm">No proposals yet.</p>
          )}
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
            {leaderboard.slice(0, 5).map((a) => (
              <li
                key={a.rawAddress}
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
      {pendingPerformanceFeeUsdc != null &&
        pendingPerformanceFeeUsdc > BigInt(0) && (
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base flex items-center gap-2">
                <Zap className="h-4 w-4" />
                Pending Fee
              </CardTitle>
            </CardHeader>
            <CardContent className="text-sm">
              <p className="text-[var(--muted-foreground)]">
                {formatAmount(pendingPerformanceFeeUsdc)} USDC
                awaiting conversion to $CEO for top 10 agents.
              </p>
            </CardContent>
          </Card>
        )}
    </aside>
  );
}
