"use client";

import { useMemo, useState } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { type Hex } from "viem";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { contractAddresses } from "@/lib/web3/addresses";
import {
  ceoVaultFunctionCatalog,
  coreUiFunctionNames,
  getFunctionArgTemplate,
} from "@/lib/contracts/devtools";

export default function DevtoolsPage() {
  const { isConnected } = useAccount();
  const publicClient = usePublicClient();
  const writeContract = useWriteContract();
  const [functionName, setFunctionName] = useState(ceoVaultFunctionCatalog[0]?.name ?? "");
  const [argsJson, setArgsJson] = useState(getFunctionArgTemplate(ceoVaultFunctionCatalog[0]?.name ?? ""));
  const [result, setResult] = useState<string>("");
  const [txHash, setTxHash] = useState<Hex | "">("");
  const [isRunning, setIsRunning] = useState(false);

  const selectedFunction = useMemo(
    () => ceoVaultFunctionCatalog.find((item) => item.name === functionName),
    [functionName]
  );
  const functionAbi = useMemo(
    () => ceoVaultAbi.find((item) => item.type === "function" && item.name === functionName),
    [functionName]
  );

  async function onRun() {
    if (!functionAbi || !publicClient) return;
    setIsRunning(true);
    setResult("");
    setTxHash("");
    try {
      const parsedArgs = JSON.parse(argsJson) as unknown[];
      if (selectedFunction?.stateMutability === "view" || selectedFunction?.stateMutability === "pure") {
        const readResult = await publicClient.readContract({
          address: contractAddresses.ceoVault,
          abi: ceoVaultAbi as never,
          functionName: functionAbi.name as never,
          args: parsedArgs as never,
        });
        setResult(JSON.stringify(readResult, (_, value) => (typeof value === "bigint" ? value.toString() : value), 2));
      } else {
        const hash = await writeContract.writeContractAsync({
          address: contractAddresses.ceoVault,
          abi: ceoVaultAbi as never,
          functionName: functionAbi.name as never,
          args: parsedArgs as never,
        });
        setTxHash(hash);
      }
    } catch (error) {
      setResult(error instanceof Error ? error.message : "Unknown error");
    } finally {
      setIsRunning(false);
    }
  }

  return (
    <main className="container mx-auto px-4 py-8 space-y-6">
      <section>
        <h1 className="text-3xl font-bold tracking-tight">Devtools</h1>
        <p className="text-[var(--muted-foreground)] mt-2 max-w-3xl">
          Advanced CEOVault function console. Core user-story functions remain in `/humans` and `/agents`; this page
          exposes the rest of the external surface.
        </p>
      </section>

      <Card>
        <CardHeader>
          <CardTitle>Function Runner</CardTitle>
          <CardDescription>Choose any CEOVault external function and execute with JSON args.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">Function</label>
            <select
              value={functionName}
              onChange={(e) => {
                setFunctionName(e.target.value);
                setArgsJson(getFunctionArgTemplate(e.target.value));
              }}
              className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
            >
              {ceoVaultFunctionCatalog.map((fn) => (
                <option key={fn.name} value={fn.name}>
                  {fn.name} ({fn.stateMutability})
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2">Args JSON</label>
            <textarea
              value={argsJson}
              onChange={(e) => setArgsJson(e.target.value)}
              rows={8}
              className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
            />
          </div>

          <div className="flex gap-3 items-center">
            <Button onClick={onRun} disabled={isRunning || !isConnected}>
              {isRunning ? "Running..." : "Run Function"}
            </Button>
            {!isConnected && (
              <span className="text-xs text-[var(--muted-foreground)]">Connect wallet to run non-view functions.</span>
            )}
          </div>

          {txHash && (
            <p className="text-xs font-mono break-all text-[var(--muted-foreground)]">
              Submitted tx: {txHash}
            </p>
          )}
          {result && (
            <pre className="text-xs font-mono overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] p-3 bg-[var(--muted)]/30">
              {result}
            </pre>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Coverage Split</CardTitle>
          <CardDescription>Core UI vs Devtools function classification.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-2 text-sm md:grid-cols-2">
          {ceoVaultFunctionCatalog.map((fn) => (
            <div key={fn.name} className="flex justify-between rounded-[var(--radius)] border border-[var(--border)] px-3 py-2">
              <span className="font-mono">{fn.name}</span>
              <span className="text-[var(--muted-foreground)]">
                {coreUiFunctionNames.has(fn.name) ? "Core UI" : "Devtools"}
              </span>
            </div>
          ))}
        </CardContent>
      </Card>
    </main>
  );
}
