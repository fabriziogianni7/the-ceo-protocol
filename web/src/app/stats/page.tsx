"use client";

import { useMemo, useState, useCallback } from "react";
import { useReadContract, useReadContracts } from "wagmi";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { VaultValueChart } from "@/components/charts/vault-value-chart";
import { MOCK_AGENT_SCORE_HISTORY } from "@/lib/mock-data";
import {
  BarChart as RechartsBarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { TrendingUp, Wallet, Users, Target, FileText, Coins, Copy, Check, ExternalLink } from "lucide-react";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { erc20Abi } from "@/lib/contracts/abi/erc20Abi";
import { erc4626Abi } from "@/lib/contracts/abi/erc4626Abi";
import { contractAddresses } from "@/lib/web3/addresses";
import { formatAmount, shortenAddress } from "@/lib/contracts/format";
import { Button } from "@/components/ui/button";

const MONADSCAN_BASE = "https://monadscan.com";

export default function StatsPage() {
  const [copied, setCopied] = useState(false);
  const copyAddress = useCallback(async () => {
    await navigator.clipboard.writeText(contractAddresses.ceoVault);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, []);
  const { data: totalAssets } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "totalAssets",
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
    const maxHistory = 14;
    const start = Math.max(1, current - maxHistory);
    return Array.from({ length: current - start + 1 }, (_, idx) => BigInt(start + idx));
  }, [currentEpoch]);

  const epochStartAssetsContracts = useMemo(
    () =>
      historicalEpochs.map((epoch) => ({
        address: contractAddresses.ceoVault,
        abi: ceoVaultAbi,
        functionName: "s_epochStartAssets" as const,
        args: [epoch],
      })),
    [historicalEpochs]
  );

  const epochStartAssetsReads = useReadContracts({
    contracts: epochStartAssetsContracts,
    query: { enabled: epochStartAssetsContracts.length > 0 },
  });

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

  const vaultValueSeries = useMemo(() => {
    const current = Number(currentEpoch ?? BigInt(0));
    if (current <= 0) return [];
    const currentVal = Number(totalAssets ?? BigInt(0)) / 1e6;
    const points: { epoch: number; value: number }[] = [];
    const reads = epochStartAssetsReads.data;
    for (let i = 0; i < historicalEpochs.length; i++) {
      const epoch = Number(historicalEpochs[i]);
      const isCurrentEpoch = epoch === current;
      const value = isCurrentEpoch
        ? currentVal
        : reads?.[i]?.status === "success"
          ? Number(reads[i].result as bigint) / 1e6
          : 0;
      points.push({ epoch, value });
    }
    return points;
  }, [
    currentEpoch,
    totalAssets,
    historicalEpochs,
    epochStartAssetsReads.data,
  ]);

  const leaderboardSeries = useMemo(() => {
    if (!leaderboardRaw) return MOCK_AGENT_SCORE_HISTORY;
    const [agents, scores] = leaderboardRaw;
    return agents.map((agent, idx) => ({
      agent: shortenAddress(agent),
      score: Number(scores[idx] ?? BigInt(0)),
    }));
  }, [leaderboardRaw]);

  const deployedSum = vaultAllocations.reduce((s, a) => s + a.value, 0) * 1e6;
  const totalAssetsRaw = totalAssets ?? BigInt(0);
  const idleRaw =
    totalAssetsRaw > BigInt(Math.floor(deployedSum))
      ? totalAssetsRaw - BigInt(Math.floor(deployedSum))
      : BigInt(0);
  const idleUsdc = Number(idleRaw) / 1e6;

  return (
    <main className="container mx-auto px-4 py-8 space-y-10">
      {/* Hero */}
      <section>
        <h1 className="text-3xl font-bold tracking-tight">Performance</h1>
       
        <div className="flex flex-wrap items-center gap-2 mt-4">
          <span className="text-sm text-[var(--muted-foreground)]">CEOVault:</span>
          <a
            href={`${MONADSCAN_BASE}/address/${contractAddresses.ceoVault}`}
            target="_blank"
            rel="noopener noreferrer"
            className="font-mono text-sm text-[var(--primary)] hover:underline inline-flex items-center gap-1"
            title="View on MonadScan"
          >
            {shortenAddress(contractAddresses.ceoVault)}
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
          <Button
            variant="ghost"
            size="sm"
            className="h-8 w-8 p-0"
            onClick={copyAddress}
            title="Copy address"
          >
            {copied ? (
              <Check className="h-4 w-4 text-green-500" />
            ) : (
              <Copy className="h-4 w-4" />
            )}
          </Button>
        </div>
      </section>

      {/* Summary cards */}
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-[var(--muted-foreground)]">
              Total Value
            </CardTitle>
            <Wallet className="h-4 w-4 text-[var(--muted-foreground)]" />
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{formatAmount(totalAssets, 6)} USD</p>
            <p className="text-xs text-[var(--muted-foreground)] mt-1">
              totalAssets — total under management
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
              Total vault value (USD) from totalAssets — sum of shares owned by the vault.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <VaultValueChart data={vaultValueSeries} />
          </CardContent>
        </Card>
      </section>

      {/* Capital deployment — whitelisted yield vaults from getYieldVaults */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle>Capital Deployment</CardTitle>
            <CardDescription>
              Whitelisted yield vaults from getYieldVaults. Each vault shows symbol and USD value (shares × convertToAssets).
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
                    <span>{a.value.toFixed(2)} USD</span>
                  </div>
                ))}
                <div className="flex items-center justify-between rounded bg-[var(--muted)]/50 px-3 py-2 text-sm">
                  <span className="font-medium text-[var(--muted-foreground)]">Idle</span>
                  <span>{idleUsdc.toFixed(2)} USD</span>
                </div>
              </div>
            ) : (
              <p className="text-sm text-[var(--muted-foreground)]">
                No yield vaults configured or loading…
              </p>
            )}
          </CardContent>
        </Card>
      </section>

      {/* Leaderboard */}
      <section>
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
      </section>

    </main>
  );
}