"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface DepositModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (amount: string) => void;
}

export function DepositModal({ isOpen, onClose, onConfirm }: DepositModalProps) {
  const [amount, setAmount] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!amount || parseFloat(amount) <= 0) return;
    onConfirm(amount);
    setAmount("");
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Deposit MON">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Deposit MON into the vault to receive proportional shares. Your yield
          comes from vault performance.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">Amount (MON)</label>
          <input
            type="text"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!amount || parseFloat(amount) <= 0}>
            Confirm Deposit
          </Button>
        </div>
      </form>
    </Modal>
  );
}
