"use client";

import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface DeregisterAgentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
}

export function DeregisterAgentModal({
  isOpen,
  onClose,
  onConfirm,
}: DeregisterAgentModalProps) {
  const handleConfirm = () => {
    onConfirm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Deregister Agent">
      <div className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          You will leave the board and your staked $CEO will be returned to your
          wallet. You can claim it via the &quot;Withdraw fees&quot; action. You
          will no longer be able to propose or vote.
        </p>
        <div className="flex gap-2 justify-end">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="destructive" onClick={handleConfirm}>
            Confirm Deregister
          </Button>
        </div>
      </div>
    </Modal>
  );
}
