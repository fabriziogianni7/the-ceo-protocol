"use client";

import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";

const CEO_TOKEN_URL = "https://nad.fun/tokens/0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777";

const DISCLAIMER = `This token is an experimental project launched for testing and exploratory purposes only. It is not intended as a financial investment, security, or any form of guaranteed asset. Participation in this token involves extreme risk, including but not limited to:

Total Loss of Funds: The value of this token could drop to zero at any time due to market volatility, technical issues, or lack of liquidity.

No Guarantees: There are no assurances of functionality, security, or future development. Bugs, exploits, or failures in the underlying smart contract or blockchain could result in irreversible losses.

Regulatory Risks: Cryptocurrencies and tokens are subject to evolving laws and regulations, which may render this token illegal or worthless in certain jurisdictions.

Speculative Nature: This is not backed by any assets, revenues, or entities. Any perceived value is purely speculative and driven by community interest, which can evaporate suddenly.

No Professional Advice: This disclaimer is not financial, legal, or investment advice. Consult qualified professionals before engaging with this token.

By interacting with this token, you acknowledge that you are doing so at your own risk and have conducted thorough due diligence (DYOR). The creator assumes no liability for any losses incurred. If you cannot afford to lose your entire investment, do not participate.`;

interface TokenDisclaimerModalProps {
  isOpen: boolean;
  onClose: () => void;
  tokenUrl?: string;
}

export function TokenDisclaimerModal({
  isOpen,
  onClose,
  tokenUrl = CEO_TOKEN_URL,
}: TokenDisclaimerModalProps) {
  const handleAccept = () => {
    window.open(tokenUrl, "_blank", "noopener,noreferrer");
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Disclaimer for Experimental Token (0xCA26...7777)"
      size="lg"
    >
      <div className="space-y-4">
        <p className="text-xs text-[var(--muted-foreground)] font-mono break-all">
          Contract: 0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777
        </p>
        <div className="max-h-[50vh] overflow-y-auto rounded-[var(--radius)] bg-[var(--muted)] p-4">
          <p className="text-sm text-[var(--muted-foreground)] whitespace-pre-line leading-relaxed">
            {DISCLAIMER}
          </p>
        </div>
        <div className="flex gap-2 justify-end pt-2">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleAccept} variant="accent">
            I Understand, Continue to nad.fun
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export { CEO_TOKEN_URL };
