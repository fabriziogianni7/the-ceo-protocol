"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface ExecuteRebalanceModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (params: {
    mode: "execute" | "convert";
    proposalId: string;
    actionsJson: string;
    minCeoOut: string;
  }) => void;
  isCEO?: boolean;
}

export function ExecuteRebalanceModal({
  isOpen,
  onClose,
  onConfirm,
  isCEO = false,
}: ExecuteRebalanceModalProps) {
  const [mode, setMode] = useState<"execute" | "convert">("execute");
  const [proposalId, setProposalId] = useState("0");
  const [minCeoOut, setMinCeoOut] = useState("0");
  const [actionsJson, setActionsJson] = useState(
    '[{"target":"0x0000000000000000000000000000000000000000","value":"0","data":"0x"}]'
  );

  const handleConfirm = () => {
    onConfirm({ mode, proposalId, actionsJson, minCeoOut });
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Execute Rebalance">
      <div className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          {isCEO
            ? "As CEO, execute the winning proposal or convert pending performance fee into $CEO."
            : "Only the CEO (top agent) can execute during the grace period. After that, the #2 agent can step in if the CEO missed the deadline."}
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">Mode</label>
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as "execute" | "convert")}
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          >
            <option value="execute">execute(proposalId, actions)</option>
            <option value="convert">convertPerformanceFee(actions, minCeoOut)</option>
          </select>
        </div>
        {mode === "execute" && (
          <div>
            <label className="block text-sm font-medium mb-2">Proposal ID</label>
            <input
              type="text"
              value={proposalId}
              onChange={(e) => setProposalId(e.target.value)}
              className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
            />
          </div>
        )}
        {mode === "convert" && (
          <div>
            <label className="block text-sm font-medium mb-2">minCeoOut (raw)</label>
            <input
              type="text"
              value={minCeoOut}
              onChange={(e) => setMinCeoOut(e.target.value)}
              className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
            />
          </div>
        )}
        <div>
          <label className="block text-sm font-medium mb-2">Actions JSON</label>
          <textarea
            rows={5}
            value={actionsJson}
            onChange={(e) => setActionsJson(e.target.value)}
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div className="flex gap-2 justify-end">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleConfirm} disabled={!isCEO}>
            {isCEO ? "Confirm Execute" : "CEO Only"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
