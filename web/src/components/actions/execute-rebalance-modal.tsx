"use client";

import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface ExecuteRebalanceModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  isCEO?: boolean;
}

export function ExecuteRebalanceModal({
  isOpen,
  onClose,
  onConfirm,
  isCEO = false,
}: ExecuteRebalanceModalProps) {
  const handleConfirm = () => {
    onConfirm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Execute Rebalance">
      <div className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          {isCEO
            ? "As CEO, you execute the winning proposal by calling the whitelisted DEX. Requires swap calldata and minMonAfter for slippage protection."
            : "Only the CEO (top agent) can execute during the grace period. After that, the #2 agent can step in if the CEO missed the deadline."}
        </p>
        <p className="text-xs text-[var(--muted-foreground)]">
          On-chain: executeRebalance(proposalId, swapCalls[], minMonAfter)
        </p>
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
