import { encodeFunctionData, type Abi, type Address, type Hex } from "viem";
import type { VaultAction } from "@/lib/contracts/types";

interface RawActionInput {
  target: string;
  value?: string;
  data: string;
}

export function parseActionsJson(actionsJson: string): VaultAction[] {
  const parsed = JSON.parse(actionsJson) as RawActionInput[];
  if (!Array.isArray(parsed)) {
    throw new Error("Actions JSON must be an array");
  }
  return parsed.map((action) => ({
    target: action.target as Address,
    value: BigInt(action.value ?? "0"),
    data: action.data as Hex,
  }));
}

export function encodeErc20ApproveAction(
  token: Address,
  spender: Address,
  amount: bigint,
  erc20Abi: Abi
): VaultAction {
  const data = encodeFunctionData({
    abi: erc20Abi,
    functionName: "approve",
    args: [spender, amount],
  });
  return {
    target: token,
    value: BigInt(0),
    data,
  };
}
