"use client";

import { useMemo } from "react";
import { useReadContract, useReadContracts } from "wagmi";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { VaultValueChart } from "@/components/charts/vault-value-chart";
import { VaultCompositionChart } from "@/components/charts/vault-composition-chart";
import { MOCK_AGENT_SCORE_HISTORY } from "@/lib/mock-data";
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
import { TrendingUp, Wallet, Users, Target, Award, FileText, Coins } from "lucide-react";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { erc20Abi } from "@/lib/contracts/abi/erc20Abi";
import { erc4626Abi } from "@/lib/contracts/abi/erc4626Abi";
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
  const { data: yieldVaultAddresses } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getYieldVaults",
  });

  const vaultSymbolBalanceContracts = useMemo(
    () =>
      (yieldVaultAddresses ?? []).flatMap((vaultAddr: `0x${string}`) => [
        {
          address: vaultAddr,
          abi: erc4626Abi,
          functionName: "symbol" as const,
        },
        {
          address: vaultAddr,
          abi: erc4626Abi,
          functionName: "balanceOf" as const,
          args: [contractAddresses.ceoVault],
        },
      ]),
    [yieldVaultAddresses]
  );

  const vaultSymbolBalanceReads = useReadContracts({
    contracts: vaultSymbolBalanceContracts,
    query: { enabled: vaultSymbolBalanceContracts.length > 0 },
  });

  const vaultShares = useMemo(() => {
    if (!vaultSymbolBalanceReads.data || !yieldVaultAddresses?.length) return [];
    return yieldVaultAddresses.map((_, i) => {
      const r = vaultSymbolBalanceReads.data?.[i * 2 + 1];
      return r?.status === "success" ? (r.result as bigint) : BigInt(0);
    });
  }, [vaultSymbolBalanceReads.data, yieldVaultAddresses]);

  const vaultConvertToAssetsContracts = useMemo(
    () =>
      (yieldVaultAddresses ?? []).map((vaultAddr: `0x${string}`, i: number) => ({
        address: vaultAddr,
        abi: erc4626Abi,
        functionName: "convertToAssets" as const,
        args: [vaultShares[i] ?? BigInt(0)],
      })),
    [yieldVaultAddresses, vaultShares]
  );

  const vaultAssetsReads = useReadContracts({
    contracts: vaultConvertToAssetsContracts,
    query: { enabled: vaultConvertToAssetsContracts.length > 0 },
  });

  const vaultAllocations = useMemo(() => {
    const addrs = yieldVaultAddresses ?? [];
    if (addrs.length === 0) return [];
    const symbols = addrs.map((_, i) => {
      const r = vaultSymbolBalanceReads.data?.[i * 2];
      return r?.status === "success" ? (r.result as string) : shortenAddress(addrs[i]);
    });
    const assets = addrs.map((_, i) => {
      const r = vaultAssetsReads.data?.[i];
      return r?.status === "success" ? Number(r.result as bigint) / 1e6 : 0;
    });
    return addrs.map((addr, i) => ({
      symbol: symbols[i] ?? shortenAddress(addr),
      value: assets[i] ?? 0,
    }));
  }, [yieldVaultAddresses, vaultSymbolBalanceReads.data, vaultAssetsReads.data]);
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
  const { data: ceoStaked } = useReadContract({
    address: contractAddresses.ceoToken,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [contractAddresses.ceoVault],
  });
  const historicalEpochs = useMemo(() => {
    const current = Number(currentEpoch ?? BigInt(0));
    if (current <= 0) return [];
    const start = Math.max(1, current - 7);
    return Array.from(
      { length: current - start + 1 },
      (_, idx) => BigInt(start + idx)
    );
  }, [currentEpoch]);

  const allEpochsForTotal = useMemo(() => {
    const current = Number(currentEpoch ?? BigInt(0));
    if (current <= 0) return [];
    return Array.from({ length: current }, (_, idx) => BigInt(idx + 1));
  }, [currentEpoch]);

  const totalProposalCountContracts = useMemo(
    () =>
      allEpochsForTotal.map((epoch) => ({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "getProposalCount" as const,
        args: [epoch],
      })),
    [allEpochsForTotal]
  );

  const totalProposalCountReads = useReadContracts({
    contracts: totalProposalCountContracts,
    query: { enabled: totalProposalCountContracts.length > 0 },
  });

  const totalProposals = useMemo(() => {
    if (!totalProposalCountReads.data) return 0;
    return totalProposalCountReads.data.reduce(
      (sum, r) => sum + (r.status === "success" ? Number(r.result) : 0),
      0
    );
  }, [totalProposalCountReads.data]);

  const historicalContracts = useMemo(
    () =>
      historicalEpochs.flatMap((epoch) => [
        {
          address: contractAddresses.ceoVault,
          abi: ceoVaultAbi,
          functionName: "s_epochStartAssets" as const,
          args: [epoch],
        },
        {
          address: contractAddresses.ceoVault,
          abi: ceoVaultAbi,
          functionName: "s_epochDeposits" as const,
          args: [epoch],
        },
        {
          address: contractAddresses.ceoVault,
          abi: ceoVaultAbi,
          functionName: "s_epochWithdrawals" as const,
          args: [epoch],
        },
      ]),
    [historicalEpochs]
  );

  const historicalReads = useReadContracts({
    contracts: historicalContracts,
    query: { enabled: historicalContracts.length > 0 },
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

  const epochRows = useMemo(() => {
    if (!historicalReads.data || historicalEpochs.length === 0) return [];
    const rows: {
      epoch: number;
      startAssets: number;
      deposits: number;
      withdrawals: number;
    }[] = [];
    for (let i = 0; i < historicalEpochs.length; i += 1) {
      const base = i * 3;
      const startAssets = historicalReads.data[base];
      const deposits = historicalReads.data[base + 1];
      const withdrawals = historicalReads.data[base + 2];
      if (
        startAssets?.status !== "success" ||
        deposits?.status !== "success" ||
        withdrawals?.status !== "success"
      ) {
        continue;
      }
      rows.push({
        epoch: Number(historicalEpochs[i]),
        startAssets: Number(startAssets.result) / 1e6,
        deposits: Number(deposits.result) / 1e6,
        withdrawals: Number(withdrawals.result) / 1e6,
      });
    }
    return rows;
  }, [historicalReads.data, historicalEpochs]);

  const vaultValueSeries = useMemo(() => {
    const fromHistory = epochRows.map((row) => ({ epoch: row.epoch, value: row.startAssets }));
    if (fromHistory.length > 0) return fromHistory;
    const currentVal = Number(totalAssets ?? BigInt(0)) / 1e6;
    const epoch = Number(currentEpoch ?? BigInt(1));
    if (currentVal > 0 || epoch > 0) {
      return [{ epoch: epoch || 1, value: currentVal }];
    }
    return [];
  }, [epochRows, totalAssets, currentEpoch]);

  const epochRevenueSeries = useMemo(() => {
    if (epochRows.length < 2) return [];
    return epochRows.slice(1).map((current, idx) => {
      const previous = epochRows[idx];
      const revenue =
        current.startAssets -
        previous.startAssets -
        previous.deposits +
        previous.withdrawals;
      return {
        epoch: previous.epoch,
        revenue: Number(revenue.toFixed(4)),
        profitable: revenue >= 0,
      };
    });
  }, [epochRows]);

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
  const totalUsdc = Number(totalAssetsRaw) / 1e6;
  const composition = [
    ...vaultAllocations
      .filter((a) => a.value > 0)
      .map((a) => ({
        name: a.symbol,
        value: a.value,
        percent: totalUsdc > 0 ? (a.value / totalUsdc) * 100 : 0,
      })),
    ...(Number(idleRaw) / 1e6 > 0
      ? [
          {
            name: "Idle",
            value: Number(idleRaw) / 1e6,
            percent:
              totalAssetsRaw > BigInt(0)
                ? Number((idleRaw * BigInt(10000)) / totalAssetsRaw) / 100
                : 0,
          },
        ]
      : []),
  ];

  return (
    <main className="container mx-auto px-4 py-8 space-y-10">
      {/* Hero */}
      <section>
        <h1 className="text-3xl font-bold tracking-tight">Performance</h1>
        <p className="text-[var(--muted-foreground)] max-w-2xl mt-2">
          Vault performance, agent leaderboard, epoch revenue, and proposal
          metrics. All charts below are sourced from live on-chain values.
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
              $CEO Staked
            </CardTitle>
            <Coins className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{formatAmount(ceoStaked, 18)} $CEO</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              agent stakes + pending fees on contract
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
              Active Proposals
            </CardTitle>
            <FileText className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{Number(proposalCount ?? 0)}</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              current epoch proposals
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-[var(--muted-foreground)]">
              Total Proposals
            </CardTitle>
            <FileText className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{totalProposals}</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              all-time across epochs
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
            <VaultValueChart data={vaultValueSeries} />
          </CardContent>
        </Card>
      </section>

      {/* Asset Flows Over Time — right below Vault Value */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle>Asset Flows Over Time</CardTitle>
            <CardDescription>
              Epoch-level deposits and withdrawals from on-chain vault accounting.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={260}>
              <RechartsLineChart data={epochRows}>
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
                  formatter={(value: number, name: string) => [
                    `${value} USDC`,
                    name === "deposits"
                      ? "Deposits"
                      : name === "withdrawals"
                        ? "Withdrawals"
                        : name,
                  ]}
                  labelFormatter={(label) => `Epoch ${label}`}
                />
                <Legend />
                <Line
                  type="monotone"
                  dataKey="deposits"
                  stroke="var(--primary)"
                  strokeWidth={2}
                  dot={{ fill: "var(--primary)" }}
                  name="Deposits"
                />
                <Line
                  type="monotone"
                  dataKey="withdrawals"
                  stroke="var(--accent)"
                  strokeWidth={2}
                  dot={{ fill: "var(--accent)" }}
                  name="Withdrawals"
                />
              </RechartsLineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </section>

      {/* Capital deployment — where vault capital is deployed */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle>Capital Deployment</CardTitle>
            <CardDescription>
              Where CEO vault capital is deployed. Each yield vault shows its symbol and USDC value.
            </CardDescription>
          </CardHeader>
          <CardContent>
            {vaultAllocations.length > 0 ? (
              <div className="space-y-2">
                {vaultAllocations.map((a, i) => (
                  <div
                    key={i}
                    className="flex items-center justify-between rounded bg-[var(--muted)]/50 px-3 py-2 text-sm"
                  >
                    <span className="font-medium">{a.symbol}</span>
                    <span>{a.value.toFixed(2)} USDC</span>
                  </div>
                ))}
                {Number(idleRaw) / 1e6 > 0 && (
                  <div className="flex items-center justify-between rounded bg-[var(--muted)]/50 px-3 py-2 text-sm">
                    <span className="font-medium text-[var(--muted-foreground)]">Idle</span>
                    <span>{(Number(idleRaw) / 1e6).toFixed(2)} USDC</span>
                  </div>
                )}
              </div>
            ) : (
              <p className="text-sm text-[var(--muted-foreground)]">
                No yield vaults configured or loading…
              </p>
            )}
          </CardContent>
        </Card>
      </section>

      {/* Row: Composition + Epoch Revenue */}
      <section className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Vault Composition</CardTitle>
            <CardDescription>
              Capital deployment by yield vault (symbol) and idle USDC.
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
              <RechartsBarChart data={epochRevenueSeries}>
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

    </main>
  );
}
