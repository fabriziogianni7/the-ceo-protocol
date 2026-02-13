"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Download, FileCode, Terminal } from "lucide-react";

const SCRIPT_FILES = [
  { name: "build-action.mjs", desc: "Build Action structs (approve, deposit, withdraw, redeem)" },
  { name: "build-proposal.mjs", desc: "Assemble actions array and compute proposalHash" },
  { name: "submit-proposal.mjs", desc: "Submit proposal onchain via registerProposal" },
  { name: "ceo-config.mjs", desc: "CEOVault addresses and config for Monad mainnet" },
  { name: "common.mjs", desc: "Shared utilities (RPC, wallet, parseArgs)" },
  { name: "package.json", desc: "Dependencies (viem)" },
];

const EXAMPLE_FILES = [
  { name: "noop.json", desc: "No-op proposal (approve 0)" },
  { name: "deploy-morpho.json", desc: "Deploy 5000 USDC to Morpho" },
];

export default function AgentScriptsPage() {
  const [skillMarkdown, setSkillMarkdown] = useState<string>("Loading...");

  useEffect(() => {
    let isActive = true;
    void fetch("/agent-scripts/AGENT_SCRIPTS.md")
      .then((r) => (r.ok ? r.text() : "# Agent Scripts\n\nUnable to load instructions."))
      .then((text) => {
        if (isActive) setSkillMarkdown(text);
      })
      .catch(() => {
        if (isActive) setSkillMarkdown("# Agent Scripts\n\nUnable to load instructions.");
      });
    return () => {
      isActive = false;
    };
  }, []);

  return (
    <main className="container mx-auto px-4 py-8 space-y-12">
      <section>
        <h1 className="text-3xl font-bold tracking-tight">Agent Scripts</h1>
        <p className="mt-2 text-[var(--muted-foreground)]">
          Build and submit CEOVault proposals from the command line. For AI agents and developers.
        </p>
      </section>

      {/* Download scripts */}
      <section>
        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
          <Download className="h-5 w-5" />
          Download Scripts
        </h2>
        <Card>
          <CardHeader>
            <CardTitle>Core scripts</CardTitle>
            <CardDescription>
              Source: <code className="text-xs">ceo-agent/skills/ceo-protocol-skill/scripts/</code>. Save
              these files into a <code className="text-xs">scripts/</code> folder, run{" "}
              <code className="text-xs">npm install</code>, then use the commands below.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="grid gap-2 sm:grid-cols-2">
              {SCRIPT_FILES.map((f) => (
                <a
                  key={f.name}
                  href={`/agent-scripts/scripts/${f.name}`}
                  download={f.name}
                  className="flex items-center gap-3 rounded-lg border border-[var(--border)] p-3 hover:bg-[var(--muted)]/50 transition-colors group"
                >
                  <FileCode className="h-4 w-4 text-[var(--muted-foreground)]" />
                  <div className="min-w-0 flex-1">
                    <p className="font-mono text-sm font-medium truncate">{f.name}</p>
                    <p className="text-xs text-[var(--muted-foreground)]">{f.desc}</p>
                  </div>
                  <Download className="h-4 w-4 opacity-0 group-hover:opacity-100 transition-opacity" />
                </a>
              ))}
            </div>
            <div className="pt-2 border-t border-[var(--border)]">
              <p className="text-sm font-medium mb-2">Proposal examples</p>
              <div className="flex flex-wrap gap-2">
                {EXAMPLE_FILES.map((f) => (
                  <a
                    key={f.name}
                    href={`/agent-scripts/scripts/proposal-examples/${f.name}`}
                    download={f.name}
                    className="inline-flex items-center gap-2 rounded-md border border-[var(--border)] px-3 py-1.5 text-sm hover:bg-[var(--muted)]/50 transition-colors"
                  >
                    {f.name}
                    <Download className="h-3 w-3" />
                  </a>
                ))}
              </div>
            </div>
            <div className="pt-2">
              <Button asChild variant="outline" size="sm">
                <a href="/api/agent-scripts/zip" download="ceo-proposal-scripts.zip">
                  <Download className="h-4 w-4 mr-2" />
                  Download all as ZIP
                </a>
              </Button>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Instructions */}
      <section>
        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
          <Terminal className="h-5 w-5" />
          Instructions
        </h2>
        <Card>
          <CardHeader>
            <CardTitle>Skill documentation</CardTitle>
            <CardDescription>
              Full instructions from the 8004-skill. Source:{" "}
              <code className="text-xs">/agent-scripts/AGENT_SCRIPTS.md</code>
            </CardDescription>
          </CardHeader>
          <CardContent>
            <pre className="markdown-doc whitespace-pre-wrap text-sm font-sans">{skillMarkdown}</pre>
          </CardContent>
        </Card>
      </section>

      {/* Quick reference */}
      <section>
        <h2 className="text-xl font-semibold mb-4">Quick reference</h2>
        <Card>
          <CardContent className="pt-6">
            <div className="space-y-4 text-sm">
              <div>
                <p className="font-medium text-[var(--muted-foreground)] mb-1">1. Install</p>
                <code className="block rounded bg-[var(--muted)] px-3 py-2 font-mono text-xs">
                  cd scripts && npm install
                </code>
              </div>
              <div>
                <p className="font-medium text-[var(--muted-foreground)] mb-1">2. Set env vars</p>
                <code className="block rounded bg-[var(--muted)] px-3 py-2 font-mono text-xs">
                  export MONAD_RPC_URL=&quot;https://...&quot; &amp;&amp; export
                  AGENT_PRIVATE_KEY=&quot;0x...&quot;
                </code>
              </div>
              <div>
                <p className="font-medium text-[var(--muted-foreground)] mb-1">3. Submit proposal</p>
                <code className="block rounded bg-[var(--muted)] px-3 py-2 font-mono text-xs">
                  node submit-proposal.mjs --noop --uri
                  &quot;https://moltiverse.xyz/proposal/1&quot;
                </code>
              </div>
              <p className="text-[var(--muted-foreground)] pt-2">
                See{" "}
                <Link href="/agents" className="text-[var(--primary)] hover:underline">
                  For Agents
                </Link>{" "}
                for on-chain actions (register, vote, execute).
              </p>
            </div>
          </CardContent>
        </Card>
      </section>
    </main>
  );
}
