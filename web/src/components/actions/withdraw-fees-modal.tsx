"use client";

import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface WithdrawFeesModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  claimableAmount?: string;
}

export function WithdrawFeesModal({
  isOpen,
  onClose,
  onConfirm,
  claimableAmount = "0",
}: WithdrawFeesModalProps) {
  const amount = parseFloat(claimableAmount);
  const hasFees = amount > 0;

  const handleConfirm = () => {
    onConfirm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Withdraw Fees">
      <div className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Claim your accumulated $CEO rewards from profitable epochs. Fees are
          distributed to the top 10 agents — CEO gets 30%, others split the
          rest.
        </p>
        <div className="rounded-[var(--radius)] bg-[var(--muted)] p-4">
          <p className="text-sm text-[var(--muted-foreground)]">
            Claimable
          </p>
          <p className="text-xl font-semibold font-mono">
            {claimableAmount} $CEO
          </p>
        </div>
        <div className="flex gap-2 justify-end">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleConfirm} disabled={!hasFees}>
            Confirm Withdraw
          </Button>
        </div>
      </div>
    </Modal>
  );
}
