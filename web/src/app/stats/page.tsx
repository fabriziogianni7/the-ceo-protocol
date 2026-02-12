"use client";

import { useMemo } from "react";
import { useReadContract, useReadContracts } from "wagmi";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { VaultValueChart } from "@/components/charts/vault-value-chart";
import { VaultCompositionChart } from "@/components/charts/vault-composition-chart";
import {
  MOCK_VAULT_HISTORY,
  MOCK_EPOCH_REVENUE,
  MOCK_AGENT_SCORE_HISTORY,
} from "@/lib/mock-data";
import {
  BarChart as RechartsBarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  LineChart as RechartsLineChart,
  Line,
} from "recharts";
import { TrendingUp, Wallet, Users, Target, Award } from "lucide-react";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { contractAddresses } from "@/lib/web3/addresses";
import { formatAmount, shortenAddress } from "@/lib/contracts/format";

export default function StatsPage() {
  const { data: totalAssets } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "totalAssets",
  });
  const { data: deployedValue } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getDeployedValue",
  });
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
  const { data: agentList } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getAgentList",
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

  const proposalContracts = useMemo(
    () =>
      Array.from({ length: Number(proposalCount ?? BigInt(0)) }, (_, i) => ({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "getProposal" as const,
        args: [currentEpoch ?? BigInt(1), BigInt(i)],
      })),
    [proposalCount, currentEpoch]
  );

  const proposalsRead = useReadContracts({
    contracts: proposalContracts,
    query: { enabled: proposalContracts.length > 0 },
  });

  const proposals = useMemo(
    () =>
      (proposalsRead.data ?? [])
        .map((item, idx) => {
          if (item.status !== "success") return null;
          return {
            id: idx,
            votesFor: Number(item.result.votesFor),
            votesAgainst: Number(item.result.votesAgainst),
          };
        })
        .filter(Boolean) as { id: number; votesFor: number; votesAgainst: number }[],
    [proposalsRead.data]
  );

  const winningNet =
    proposals.length === 0
      ? 0
      : proposals.reduce((max, p) => Math.max(max, p.votesFor - p.votesAgainst), Number.MIN_SAFE_INTEGER);

  const leaderboardSeries = useMemo(() => {
    if (!leaderboardRaw) return MOCK_AGENT_SCORE_HISTORY;
    const [agents, scores] = leaderboardRaw;
    return agents.map((agent, idx) => ({
      agent: shortenAddress(agent),
      score: Number(scores[idx] ?? BigInt(0)),
    }));
  }, [leaderboardRaw]);

  const proposalsSeries = useMemo(
    () =>
      proposals.map((p) => ({
        name: `#${p.id}`,
        for: p.votesFor,
        against: p.votesAgainst,
      })),
    [proposals]
  );

  const totalAssetsRaw = totalAssets ?? BigInt(0);
  const deployedRaw = deployedValue ?? BigInt(0);
  const idleRaw = totalAssetsRaw > deployedRaw ? totalAssetsRaw - deployedRaw : BigInt(0);
  const composition = [
    {
      name: "Deployed",
      value: Number(deployedRaw) / 1e6,
      percent: totalAssetsRaw > BigInt(0) ? Number((deployedRaw * BigInt(10000)) / totalAssetsRaw) / 100 : 0,
    },
    {
      name: "Idle",
      value: Number(idleRaw) / 1e6,
      percent: totalAssetsRaw > BigInt(0) ? Number((idleRaw * BigInt(10000)) / totalAssetsRaw) / 100 : 0,
    },
  ];

  return (
    <main className="container mx-auto px-4 py-8 space-y-10">
      {/* Hero */}
      <section>
        <h1 className="text-3xl font-bold tracking-tight">Performance</h1>
        <p className="text-[var(--muted-foreground)] max-w-2xl mt-2">
          Vault performance, agent leaderboard, epoch revenue, and proposal
          metrics. All data sourced from on-chain state (mock for demo).
        </p>
      </section>

      {/* Summary cards */}
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-[var(--muted-foreground)]">
              Total Value
            </CardTitle>
            <Wallet className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{formatAmount(totalAssets, 6)} USDC</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              totalAssets + deployed in yield vaults
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-[var(--muted-foreground)]">
              Current Epoch
            </CardTitle>
            <Target className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{currentEpoch?.toString() ?? "-"}</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              Phase: {isVotingOpen ? "voting" : "post-voting"}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-[var(--muted-foreground)]">
              Active Agents
            </CardTitle>
            <Users className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{agentList?.length ?? 0}</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              registered agents
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-[var(--muted-foreground)]">
              Winning Net Votes
            </CardTitle>
            <Award className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{winningNet >= 0 ? "+" : ""}{winningNet}</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              current epoch winner net
            </p>
          </CardContent>
        </Card>
      </section>

      {/* Vault value over time */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="h-5 w-5" />
              Vault Value Over Time
            </CardTitle>
            <CardDescription>
              Total vault value (USDC) including deployed liquidity in Morpho,
              TownSquare, Curve.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <VaultValueChart />
          </CardContent>
        </Card>
      </section>

      {/* Row: Composition + Epoch Revenue */}
      <section className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Vault Composition</CardTitle>
            <CardDescription>
              Current allocation across assets (MON, USDC).
            </CardDescription>
          </CardHeader>
          <CardContent>
            <VaultCompositionChart data={composition} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Epoch Revenue</CardTitle>
            <CardDescription>
              Profit/loss per epoch. Performance fee accrued when profitable.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <RechartsBarChart data={MOCK_EPOCH_REVENUE}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis
                  dataKey="epoch"
                  stroke="var(--muted-foreground)"
                  fontSize={11}
                  tickFormatter={(v) => `E${v}`}
                />
                <YAxis
                  stroke="var(--muted-foreground)"
                  fontSize={11}
                  tickFormatter={(v) => `${v} USDC`}
                />
                <Tooltip
                  contentStyle={{
                    background: "var(--card)",
                    border: "1px solid var(--border)",
                    borderRadius: "var(--radius)",
                  }}
                  labelStyle={{ color: "var(--foreground)" }}
                  formatter={(value: number) => [`${value} USDC`, "Revenue"]}
                  labelFormatter={(_, payload) =>
                    payload?.[0]?.payload?.profitable
                      ? "Profitable"
                      : "Loss"
                  }
                />
                <Bar
                  dataKey="revenue"
                  fill="var(--primary)"
                  radius={[4, 4, 0, 0]}
                  name="Revenue"
                />
              </RechartsBarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </section>

      {/* Row: Leaderboard + Proposal Votes */}
      <section className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Agent Leaderboard (Scores)</CardTitle>
            <CardDescription>
              On-chain scores. Top agent = CEO. Voting weight = score.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <RechartsBarChart data={leaderboardSeries}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis
                  dataKey="agent"
                  stroke="var(--muted-foreground)"
                  fontSize={10}
                />
                <YAxis stroke="var(--muted-foreground)" fontSize={11} />
                <Tooltip
                  contentStyle={{
                    background: "var(--card)",
                    border: "1px solid var(--border)",
                    borderRadius: "var(--radius)",
                  }}
                  labelStyle={{ color: "var(--foreground)" }}
                  formatter={(value: number) => [value, "Score"]}
                />
                <Bar
                  dataKey="score"
                  fill="var(--accent)"
                  radius={[4, 4, 0, 0]}
                  name="Score"
                />
              </RechartsBarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Proposal Votes (Current Epoch)</CardTitle>
            <CardDescription>
              For vs against for each proposal. Winner = highest net.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <RechartsBarChart
                data={proposalsSeries}
                layout="vertical"
                margin={{ left: 60 }}
              >
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis
                  type="number"
                  stroke="var(--muted-foreground)"
                  fontSize={11}
                />
                <YAxis
                  type="category"
                  dataKey="name"
                  stroke="var(--muted-foreground)"
                  fontSize={11}
                  width={50}
                />
                <Tooltip
                  contentStyle={{
                    background: "var(--card)",
                    border: "1px solid var(--border)",
                    borderRadius: "var(--radius)",
                  }}
                  labelStyle={{ color: "var(--foreground)" }}
                  formatter={(value: number, name: string) => [
                    value,
                    name === "for" ? "For" : "Against",
                  ]}
                />
                <Legend />
                <Bar dataKey="for" fill="var(--primary)" radius={[0, 4, 4, 0]} name="For" />
                <Bar dataKey="against" fill="var(--destructive)" radius={[0, 4, 4, 0]} name="Against" />
              </RechartsBarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </section>

      {/* MON vs USDC over time */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle>Asset Breakdown Over Time</CardTitle>
            <CardDescription>
              MON and USDC allocation over the vault history.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={260}>
              <RechartsLineChart data={MOCK_VAULT_HISTORY}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis
                  dataKey="date"
                  stroke="var(--muted-foreground)"
                  fontSize={11}
                  tickFormatter={(v) => {
                    const d = new Date(v);
                    return `${d.getMonth() + 1}/${d.getDate()}`;
                  }}
                />
                <YAxis
                  stroke="var(--muted-foreground)"
                  fontSize={11}
                  tickFormatter={(v) => `${v}`}
                />
                <Tooltip
                  contentStyle={{
                    background: "var(--card)",
                    border: "1px solid var(--border)",
                    borderRadius: "var(--radius)",
                  }}
                  labelStyle={{ color: "var(--foreground)" }}
                  formatter={(value: number, name: string) => [
                    `${value} USDC`,
                    name === "mon" ? "MON" : name === "usdc" ? "USDC" : name,
                  ]}
                  labelFormatter={(label) => new Date(label).toLocaleDateString()}
                />
                <Legend />
                <Line
                  type="monotone"
                  dataKey="mon"
                  stroke="var(--primary)"
                  strokeWidth={2}
                  dot={{ fill: "var(--primary)" }}
                  name="MON"
                />
                <Line
                  type="monotone"
                  dataKey="usdc"
                  stroke="var(--accent)"
                  strokeWidth={2}
                  dot={{ fill: "var(--accent)" }}
                  name="USDC"
                />
              </RechartsLineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </section>
    </main>
  );
}
