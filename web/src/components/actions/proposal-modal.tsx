"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface ProposalModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (params: { proposalURI: string }) => void;
}

export function ProposalModal({
  isOpen,
  onClose,
  onConfirm,
}: ProposalModalProps) {
  const [proposalURI, setProposalURI] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!proposalURI.trim()) return;
    onConfirm({ proposalURI: proposalURI.trim() });
    setProposalURI("");
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Submit Proposal">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Submit an off-chain proposal (e.g., target allocation like
          &quot;70% MON, 30% USDC&quot;). The proposal hash will be registered
          on-chain. Costs a small amount of $CEO to prevent spam.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">
            Proposal URI (IPFS / HTTP)
          </label>
          <input
            type="text"
            value={proposalURI}
            onChange={(e) => setProposalURI(e.target.value)}
            placeholder="ipfs://Qm... or https://..."
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!proposalURI.trim()}>
            Confirm Submit
          </Button>
        </div>
      </form>
    </Modal>
  );
}
