"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (shares: string) => void;
  maxShares?: string;
}

export function WithdrawModal({
  isOpen,
  onClose,
  onConfirm,
  maxShares = "100",
}: WithdrawModalProps) {
  const [shares, setShares] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!shares || parseFloat(shares) <= 0) return;
    onConfirm(shares);
    setShares("");
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Withdraw MON">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Burn vault shares to receive your proportional MON back. Withdrawals
          are processed instantly.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">
            Shares to burn
          </label>
          <input
            type="text"
            value={shares}
            onChange={(e) => setShares(e.target.value)}
            placeholder="0.00"
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
          <p className="text-xs text-[var(--muted-foreground)] mt-1">
            Max: {maxShares} shares
          </p>
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!shares || parseFloat(shares) <= 0}>
            Confirm Withdraw
          </Button>
        </div>
      </form>
    </Modal>
  );
}
