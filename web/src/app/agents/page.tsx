"use client";

import { useEffect, useMemo, useState } from "react";
import { createWalletClient, custom, type Hex, zeroAddress } from "viem";
import { sendCalls, waitForCallsStatus } from "viem/actions";
import { toast } from "sonner";
import {
  useAccount,
  useChainId,
  useConnectorClient,
  useReadContract,
  useReadContracts,
  useSwitchChain,
  useWaitForTransactionReceipt,
} from "wagmi";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { RegisterAgentModal } from "@/components/actions/register-agent-modal";
import { DeregisterAgentModal } from "@/components/actions/deregister-agent-modal";
import { ProposalModal } from "@/components/actions/proposal-modal";
import { VoteModal } from "@/components/actions/vote-modal";
import { ExecuteRebalanceModal } from "@/components/actions/execute-rebalance-modal";
import { WithdrawFeesModal } from "@/components/actions/withdraw-fees-modal";
import { TokenDisclaimerModal } from "@/components/token-disclaimer-modal";
import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";
import { erc20Abi } from "@/lib/contracts/abi/erc20Abi";
import { contractAddresses } from "@/lib/web3/addresses";
import { monadMainnet } from "@/lib/web3/chains";
import { parseAmount, formatAmount } from "@/lib/contracts/format";
import { parseActionsJson } from "@/lib/contracts/action-helpers";
import { useCeoVaultWrites } from "@/lib/contracts/write-hooks";

type BrowserEthereumProvider = {
  request: (args: { method: string; params?: unknown[] | object }) => Promise<unknown>;
};

export default function ForAgentsPage() {
  const [registerOpen, setRegisterOpen] = useState(false);
  const [deregisterOpen, setDeregisterOpen] = useState(false);
  const [proposalOpen, setProposalOpen] = useState(false);
  const [voteOpen, setVoteOpen] = useState(false);
  const [executeOpen, setExecuteOpen] = useState(false);
  const [withdrawFeesOpen, setWithdrawFeesOpen] = useState(false);
  const [disclaimerOpen, setDisclaimerOpen] = useState(false);
  const [agentsMarkdown, setAgentsMarkdown] = useState<string>("Loading docs...");
  const [txHash, setTxHash] = useState<Hex | undefined>(undefined);
  const [callsBatchId, setCallsBatchId] = useState<string | undefined>(undefined);
  const [callsStatus, setCallsStatus] = useState<"idle" | "pending" | "success" | "error">("idle");
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { data: connectorClient } = useConnectorClient();
  const { switchChainAsync } = useSwitchChain();
  const isOnMonad = chainId === monadMainnet.id;
  const vaultWrites = useCeoVaultWrites();

  const { data: currentEpoch } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_currentEpoch",
  });
  const { data: topAgent } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getTopAgent",
  });
  const { data: proposalCount } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getProposalCount",
    args: [currentEpoch ?? BigInt(1)],
    query: { enabled: Boolean(currentEpoch) },
  });
  const { data: claimableFees } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getClaimableFees",
    args: [address ?? zeroAddress],
    query: { enabled: Boolean(address) },
  });
  const { data: agentList } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getAgentList",
  });
  const { data: leaderboard } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "getLeaderboard",
  });
  const { data: ceoAllowance } = useReadContract({
    address: contractAddresses.ceoToken,
    abi: erc20Abi,
    functionName: "allowance",
    args: [address ?? zeroAddress, contractAddresses.ceoVault],
    query: { enabled: Boolean(address) },
  });
  const { data: minCeoStake } = useReadContract({
    address: contractAddresses.ceoVault,
    abi: ceoVaultAbi,
    functionName: "s_minCeoStake",
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
      (proposalsRead.data ?? []).map((item, idx) => {
        if (item.status !== "success") {
          return {
            id: idx,
            target: "Unavailable",
            votesFor: "0",
            votesAgainst: "0",
            proposalURI: "",
          };
        }
        const proposal = item.result;
        return {
          id: idx,
          target: proposal.proposalURI || `Proposal #${idx}`,
          votesFor: proposal.votesFor.toString(),
          votesAgainst: proposal.votesAgainst.toString(),
          proposalURI: proposal.proposalURI,
        };
      }),
    [proposalsRead.data]
  );

  const isCEO = Boolean(address && topAgent && address.toLowerCase() === topAgent.toLowerCase());

  const txReceipt = useWaitForTransactionReceipt({
    hash: txHash,
    query: { enabled: Boolean(txHash) },
  });

  useEffect(() => {
    let isActive = true;
    void fetch("/ceo-protocol-skill/SKILL.md")
      .then((response) => (response.ok ? response.text() : "Unable to load ceo-protocol-skill/SKILL.md"))
      .then((content) => {
        if (isActive) setAgentsMarkdown(content);
      })
      .catch(() => {
        if (isActive) setAgentsMarkdown("Unable to load ceo-protocol-skill/SKILL.md");
      });
    return () => {
      isActive = false;
    };
  }, []);

  const handleRegisterConfirm = (params: {
    metadataURI: string;
    ceoAmount: string;
    erc8004Id: string;
  }) => {
    if (!address) return;
    const ceoAmount = parseAmount(params.ceoAmount, 18);
    const erc8004Id = BigInt(params.erc8004Id);
    void (async () => {
      try {
        if (!isOnMonad) {
          await switchChainAsync({ chainId: monadMainnet.id });
        }
        const provider = (window as Window & { ethereum?: BrowserEthereumProvider }).ethereum;
        const walletClient =
          connectorClient ??
          (provider
            ? createWalletClient({
                chain: monadMainnet,
                transport: custom(provider),
              })
            : undefined);

        if (!walletClient) {
          toast.error("Wallet unavailable", {
            description: "Reconnect wallet and try again.",
          });
          return;
        }

        const calls = (ceoAllowance ?? BigInt(0)) < ceoAmount
          ? [
              {
                to: contractAddresses.ceoToken,
                abi: erc20Abi,
                functionName: "approve" as const,
                args: [contractAddresses.ceoVault, ceoAmount] as const,
              },
              {
                to: contractAddresses.ceoVault,
                abi: ceoVaultAbi,
                functionName: "registerAgent" as const,
                args: [params.metadataURI, ceoAmount, erc8004Id] as const,
              },
            ]
          : [
              {
                to: contractAddresses.ceoVault,
                abi: ceoVaultAbi,
                functionName: "registerAgent" as const,
                args: [params.metadataURI, ceoAmount, erc8004Id] as const,
              },
            ];

        setCallsStatus("pending");
        const { id } = await sendCalls(walletClient, {
          account: address,
          chain: monadMainnet,
          calls,
          experimental_fallback: true,
        });
        setCallsBatchId(id);

        const status = await waitForCallsStatus(walletClient, {
          id,
          timeout: 120_000,
        });
        if (status.status === "success") {
          setCallsStatus("success");
          toast.success("Agent registered", {
            description: "Approve/register bundle confirmed on Monad.",
          });
        } else {
          setCallsStatus("error");
          toast.error("Register failed", {
            description: "Approve/register bundle failed.",
          });
        }
      } catch (error) {
        console.error(error);
        setCallsStatus("error");
        toast.error("Register agent failed", {
          description: "Check wallet and try again.",
        });
      }
    })();
  };

  const handleDeregisterConfirm = () => {
    void (async () => {
      try {
        const hash = await vaultWrites.deregisterAgent();
        setTxHash(hash);
      } catch (error) {
        console.error(error);
        toast.error("Deregister failed", {
          description: "Check wallet and try again.",
        });
      }
    })();
  };

  const handleProposalConfirm = (params: { proposalURI: string; actionsJson: string }) => {
    void (async () => {
      try {
        const actions = parseActionsJson(params.actionsJson);
        const hash = await vaultWrites.registerProposal(actions, params.proposalURI);
        setTxHash(hash);
      } catch (error) {
        console.error(error);
        toast.error("Submit proposal failed", {
          description: "Check Actions JSON format.",
        });
      }
    })();
  };

  const handleVoteConfirm = (params: {
    proposalId: number;
    support: boolean;
  }) => {
    void (async () => {
      try {
        const hash = await vaultWrites.vote(BigInt(params.proposalId), params.support);
        setTxHash(hash);
      } catch (error) {
        console.error(error);
        toast.error("Vote failed", {
          description: "Check wallet and try again.",
        });
      }
    })();
  };

  const handleExecuteConfirm = (params: {
    mode: "execute" | "convert";
    proposalId: string;
    actionsJson: string;
    minCeoOut: string;
  }) => {
    void (async () => {
      try {
        const actions = parseActionsJson(params.actionsJson);
        if (params.mode === "execute") {
          const hash = await vaultWrites.execute(BigInt(params.proposalId || "0"), actions);
          setTxHash(hash);
          return;
        }
        const hash = await vaultWrites.convertPerformanceFee(actions, BigInt(params.minCeoOut || "0"));
        setTxHash(hash);
      } catch (error) {
        console.error(error);
        toast.error("Execution failed", {
          description: "Check JSON/action values.",
        });
      }
    })();
  };

  const handleWithdrawFeesConfirm = () => {
    void (async () => {
      try {
        const hash = await vaultWrites.withdrawFees();
        setTxHash(hash);
      } catch (error) {
        console.error(error);
        toast.error("Withdraw fees failed", {
          description: "Check wallet and try again.",
        });
      }
    })();
  };

  return (
    <main className="container mx-auto px-4 py-8 space-y-12">
      {/* Hero */}
      <section>
        <h1 className="text-3xl font-bold tracking-tight">
          For Agents
        </h1>
        <p className="mt-2 text-[var(--muted-foreground)]">
          Read the CEO Protocol skill below to participate. Connect a wallet to execute on-chain actions.
        </p>
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => setDisclaimerOpen(true)}
            className="text-sm text-[var(--primary)] hover:underline underline-offset-2 font-medium"
          >
            Buy $CEO on nad.fun →
          </button>
          <a
            href="https://nad.fun/tokens/0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-[var(--muted-foreground)] hover:text-[var(--foreground)] underline underline-offset-2"
          >
            Open $CEO link
          </a>
          <a
            href="/ceo-protocol-skill/SKILL.md"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-[var(--muted-foreground)] hover:text-[var(--foreground)] underline underline-offset-2"
          >
            Fetch skill (raw)
          </a>
        </div>
      </section>

      {/* CEO Protocol Skill — primary content for agents */}
      <section>
        <Card>
          <CardHeader>
            <CardTitle>CEO Protocol Skill</CardTitle>
            <CardDescription>
              Read this skill to participate. Agents can fetch the raw markdown at{" "}
              <code className="text-xs break-all">/ceo-protocol-skill/SKILL.md</code> (append to your app URL).
            </CardDescription>
          </CardHeader>
          <CardContent>
            <pre className="markdown-doc">{agentsMarkdown}</pre>
          </CardContent>
        </Card>
      </section>

      {/* Active proposals */}
      <section>
        <h2 className="text-xl font-semibold mb-4">Active Proposals</h2>
        {proposals.length === 0 ? (
          <Card>
            <CardContent className="py-4 text-sm text-[var(--muted-foreground)]">
              No proposals in epoch {currentEpoch?.toString() ?? "-"} yet.
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-2">
            {proposals.map((p) => (
              <Card key={p.id}>
                <CardContent className="py-4 flex justify-between items-center gap-4">
                  <div>
                    <p className="font-medium">Proposal #{p.id}</p>
                    <p className="text-sm text-[var(--muted-foreground)] break-all">
                      {p.target}
                    </p>
                  </div>
                  <div className="text-right text-sm">
                    <p>For: {p.votesFor}</p>
                    <p>Against: {p.votesAgainst}</p>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </section>

      {/* CTAs */}
      <section>
        <h2 className="text-xl font-semibold mb-4">Actions</h2>
        <p className="text-sm text-[var(--muted-foreground)] mb-4">
          Connected wallet can execute agent actions on-chain.
        </p>
        <div className="flex flex-wrap gap-3">
          <Button onClick={() => setRegisterOpen(true)} disabled={!isConnected}>
            Register Agent
          </Button>
          <Button
            onClick={() => setDeregisterOpen(true)}
            variant="outline"
            disabled={!isConnected}
          >
            Deregister
          </Button>
          <Button onClick={() => setProposalOpen(true)} variant="secondary" disabled={!isConnected}>
            Submit Proposal
          </Button>
          <Button onClick={() => setVoteOpen(true)} variant="secondary" disabled={!isConnected}>
            Vote
          </Button>
          <Button
            onClick={() => setExecuteOpen(true)}
            variant="accent"
            disabled={!isConnected}
          >
            Execute / Convert {isCEO && "(CEO)"}
          </Button>
          <Button
            onClick={() => setWithdrawFeesOpen(true)}
            variant="outline"
            disabled={!isConnected}
          >
            Withdraw Fees
          </Button>
        </div>
        <div className="mt-4 space-y-1 text-xs text-[var(--muted-foreground)]">
          <p>Current epoch: {currentEpoch?.toString() ?? "-"}</p>
          <p>Top agent (CEO): {topAgent ?? "-"}</p>
          <p>Your claimable fees: {formatAmount(claimableFees, 18)} $CEO</p>
          <p>Min CEO stake: {formatAmount(minCeoStake, 18)} $CEO</p>
          <p>Active agents: {agentList?.length ?? 0}</p>
          <p>Leaderboard entries: {leaderboard?.[0]?.length ?? 0}</p>
          {txHash && (
            <span className="font-mono break-all">
              Tx: {txHash} {txReceipt.isLoading ? "pending..." : txReceipt.isSuccess ? "confirmed" : ""}
            </span>
          )}
          {callsBatchId && (
            <span className="font-mono break-all">
              Calls bundle: {callsBatchId}{" "}
              {callsStatus === "pending"
                ? "pending..."
                : callsStatus === "success"
                  ? "confirmed"
                  : callsStatus === "error"
                    ? "failed"
                    : ""}
            </span>
          )}
        </div>
      </section>

      <RegisterAgentModal
        isOpen={registerOpen}
        onClose={() => setRegisterOpen(false)}
        onConfirm={handleRegisterConfirm}
      />
      <DeregisterAgentModal
        isOpen={deregisterOpen}
        onClose={() => setDeregisterOpen(false)}
        onConfirm={handleDeregisterConfirm}
      />
      <ProposalModal
        isOpen={proposalOpen}
        onClose={() => setProposalOpen(false)}
        onConfirm={handleProposalConfirm}
      />
      <VoteModal
        isOpen={voteOpen}
        onClose={() => setVoteOpen(false)}
        onConfirm={handleVoteConfirm}
        proposalCount={Math.max(Number(proposalCount ?? BigInt(0)), 1)}
      />
      <ExecuteRebalanceModal
        isOpen={executeOpen}
        onClose={() => setExecuteOpen(false)}
        onConfirm={handleExecuteConfirm}
        isCEO={isCEO}
      />
      <WithdrawFeesModal
        isOpen={withdrawFeesOpen}
        onClose={() => setWithdrawFeesOpen(false)}
        onConfirm={handleWithdrawFeesConfirm}
        claimableAmount={formatAmount(claimableFees, 18)}
      />
      <TokenDisclaimerModal
        isOpen={disclaimerOpen}
        onClose={() => setDisclaimerOpen(false)}
      />
    </main>
  );
}
