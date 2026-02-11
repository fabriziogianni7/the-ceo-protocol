"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface VoteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (params: { proposalId: number; support: boolean }) => void;
  proposalCount?: number;
}

export function VoteModal({
  isOpen,
  onClose,
  onConfirm,
  proposalCount = 3,
}: VoteModalProps) {
  const [proposalId, setProposalId] = useState(0);
  const [support, setSupport] = useState(true);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (proposalId < 0 || proposalId >= proposalCount) return;
    onConfirm({ proposalId, support });
    setProposalId(0);
    setSupport(true);
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Vote on Proposal">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Your vote weight is based on your leaderboard score. You must have $CEO
          staked to vote.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">Proposal ID</label>
          <select
            value={proposalId}
            onChange={(e) => setProposalId(parseInt(e.target.value, 10))}
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          >
            {Array.from({ length: proposalCount }, (_, i) => (
              <option key={i} value={i}>
                Proposal #{i}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium mb-2">Vote</label>
          <div className="flex gap-4">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="support"
                checked={support}
                onChange={() => setSupport(true)}
              />
              <span>For</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="support"
                checked={!support}
                onChange={() => setSupport(false)}
              />
              <span>Against</span>
            </label>
          </div>
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit">Confirm Vote</Button>
        </div>
      </form>
    </Modal>
  );
}
