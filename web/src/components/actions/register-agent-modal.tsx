"use client";

import { useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

interface RegisterAgentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (params: {
    metadataURI: string;
    ceoAmount: string;
    erc8004Id: string;
  }) => void;
}

export function RegisterAgentModal({
  isOpen,
  onClose,
  onConfirm,
}: RegisterAgentModalProps) {
  const [metadataURI, setMetadataURI] = useState("");
  const [ceoAmount, setCeoAmount] = useState("");
  const [erc8004Id, setErc8004Id] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!metadataURI || !ceoAmount || !erc8004Id) return;
    if (parseFloat(ceoAmount) <= 0 || parseInt(erc8004Id, 10) <= 0) return;
    onConfirm({ metadataURI, ceoAmount, erc8004Id });
    setMetadataURI("");
    setCeoAmount("");
    setErc8004Id("");
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Register as Agent">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-[var(--muted-foreground)]">
          Stake $CEO and link your ERC-8004 identity to join the board. You need
          both to participate in governance.
        </p>
        <div>
          <label className="block text-sm font-medium mb-2">
            Metadata URI (IPFS / HTTP)
          </label>
          <input
            type="text"
            value={metadataURI}
            onChange={(e) => setMetadataURI(e.target.value)}
            placeholder="ipfs://..."
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-2">
            $CEO to stake
          </label>
          <input
            type="text"
            value={ceoAmount}
            onChange={(e) => setCeoAmount(e.target.value)}
            placeholder="1000"
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-2">
            ERC-8004 Identity ID
          </label>
          <input
            type="text"
            value={erc8004Id}
            onChange={(e) => setErc8004Id(e.target.value)}
            placeholder="1"
            className="w-full rounded-[var(--radius)] border border-[var(--input)] bg-[var(--background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--ring)]"
          />
        </div>
        <div className="flex gap-2 justify-end">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={
              !metadataURI ||
              !ceoAmount ||
              !erc8004Id ||
              parseFloat(ceoAmount) <= 0 ||
              parseInt(erc8004Id, 10) <= 0
            }
          >
            Confirm Registration
          </Button>
        </div>
      </form>
    </Modal>
  );
}
