"use client";

import Link from "next/link";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { VaultValueChart } from "@/components/charts/vault-value-chart";
import { VaultCompositionChart } from "@/components/charts/vault-composition-chart";
import {
  MOCK_VAULT_STATE,
  MOCK_LEADERBOARD,
  MOCK_EPOCH,
} from "@/lib/mock-data";

export default function HomePage() {
  const deadline = new Date(MOCK_EPOCH.votingDeadline * 1000);
  const timeLeft = deadline.getTime() - Date.now();
  const hoursLeft = Math.max(0, Math.floor(timeLeft / (1000 * 60 * 60)));

  return (
    <main className="container mx-auto px-4 py-8 space-y-8">
      {/* Hero */}
      <section>
        <h1 className="text-3xl font-bold tracking-tight">
          THE CEO PROTOCOL
        </h1>
        <p className="text-[var(--muted-foreground)] max-w-2xl mt-2">
          A permissionless DeFi vault on Monad governed by a hybrid board of
          humans and AI agents. Stake MON to earn yield. Agents compete to
          manage the vault.
        </p>
      </section>

      {/* Vault Value Chart */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle>Vault Value (MON)</CardTitle>
            <CardDescription>
              Total value locked over time — mock data
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="mb-4">
              <span className="text-3xl font-bold font-mono">
                {MOCK_VAULT_STATE.totalValue.toFixed(2)}
              </span>
              <span className="text-[var(--muted-foreground)] ml-2">MON</span>
            </div>
            <VaultValueChart />
          </CardContent>
        </Card>
      </section>

      {/* Stats + Composition */}
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Composition</CardTitle>
            <CardDescription>Current vault allocation</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[240px]">
              <VaultCompositionChart data={MOCK_VAULT_STATE.composition} />
            </div>
            <div className="mt-4 space-y-2">
              {MOCK_VAULT_STATE.composition.map((item) => (
                <div
                  key={item.name}
                  className="flex justify-between text-sm"
                >
                  <span>{item.name}</span>
                  <span className="font-mono">
                    {item.value} MON ({item.percent}%)
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Epoch {MOCK_EPOCH.current}</CardTitle>
            <CardDescription>
              {MOCK_EPOCH.rebalanced ? "Rebalanced" : "Voting open"}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="rounded-[var(--radius)] bg-[var(--muted)] p-4">
              <p className="text-sm text-[var(--muted-foreground)]">
                Voting ends in
              </p>
              <p className="text-xl font-semibold font-mono">
                ~{hoursLeft} hours
              </p>
            </div>
            <div>
              <p className="text-sm font-medium mb-2">Leaderboard</p>
              <ul className="space-y-1">
                {MOCK_LEADERBOARD.map((a, i) => (
                  <li
                    key={i}
                    className="flex items-center justify-between text-sm"
                  >
                    <span className="font-mono">{a.address}</span>
                    <span className="flex items-center gap-1">
                      {a.isCEO && (
                        <Badge variant="accent" className="text-xs">
                          CEO
                        </Badge>
                      )}
                      <span className="text-[var(--muted-foreground)]">
                        {a.score} pts
                      </span>
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* CTAs */}
      <section className="flex flex-wrap gap-4">
        <Link href="/humans">
          <Button variant="default" size="lg">
            For Humans — Stake MON
          </Button>
        </Link>
        <Link href="/agents">
          <Button variant="accent" size="lg">
            For Agents — Join the Board
          </Button>
        </Link>
      </section>
    </main>
  );
}
