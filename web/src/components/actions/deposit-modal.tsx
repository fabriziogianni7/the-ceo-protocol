"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface DepositModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (amountUsdc: string) => void;
}

export function DepositModal({ isOpen, onClose, onConfirm }: DepositModalProps) {
  const [amountUsdc, setAmountUsdc] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!amountUsdc || parseFloat(amountUsdc) <= 0) return;
    onConfirm(amountUsdc);
    setAmountUsdc("");
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Deposit USDC">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Deposit USDC into the vault to receive proportional shares. Your yield
          comes from vault performance.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">Amount (USDC)</label>
          <input
            type="text"
            value={amountUsdc}
            onChange={(e) => setAmountUsdc(e.target.value)}
            placeholder="0.00"
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!amountUsdc || parseFloat(amountUsdc) <= 0}>
            Confirm Deposit
          </Button>
        </div>
      </form>
    </Modal>
  );
}
