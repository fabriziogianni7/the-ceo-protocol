"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (assetsUsdc: string) => void;
  maxAssets?: string;
}

export function WithdrawModal({
  isOpen,
  onClose,
  onConfirm,
  maxAssets = "0",
}: WithdrawModalProps) {
  const [assetsUsdc, setAssetsUsdc] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!assetsUsdc || parseFloat(assetsUsdc) <= 0) return;
    onConfirm(assetsUsdc);
    setAssetsUsdc("");
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Withdraw USDC">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Burn vault shares to receive your proportional USDC back. Withdrawals
          are processed instantly.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">
            Assets to withdraw (USDC)
          </label>
          <input
            type="text"
            value={assetsUsdc}
            onChange={(e) => setAssetsUsdc(e.target.value)}
            placeholder="0.00"
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
          <p className="text-xs text-[var(--muted-foreground)] mt-1">
            Max: {maxAssets} USDC
          </p>
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!assetsUsdc || parseFloat(assetsUsdc) <= 0}>
            Confirm Withdraw
          </Button>
        </div>
      </form>
    </Modal>
  );
}
