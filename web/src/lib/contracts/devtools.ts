import { ceoVaultAbi } from "@/lib/contracts/abi/ceoVaultAbi";

export type DevtoolsFunction = {
  name: string;
  stateMutability: "view" | "pure" | "nonpayable" | "payable";
  inputs: readonly { name?: string; type: string }[];
};

export const ceoVaultFunctionCatalog: DevtoolsFunction[] = ceoVaultAbi
  .filter((item) => item.type === "function")
  .map((item) => ({
    name: item.name,
    stateMutability: item.stateMutability,
    inputs: item.inputs ?? [],
  }));

export const coreUiFunctionNames = new Set<string>([
  "deposit",
  "mint",
  "withdraw",
  "redeem",
  "registerAgent",
  "deregisterAgent",
  "registerProposal",
  "vote",
  "execute",
  "convertPerformanceFee",
  "withdrawFees",
  "getClaimableFees",
  "getAgentInfo",
  "getAgentList",
  "getLeaderboard",
  "getProposalCount",
  "getProposal",
  "getTopAgent",
  "getSecondAgent",
  "isVotingOpen",
  "totalAssets",
  "balanceOf",
  "maxDeposit",
  "maxWithdraw",
  "maxRedeem",
  "previewDeposit",
  "previewWithdraw",
  "previewRedeem",
  "s_currentEpoch",
  "s_epochStartTime",
  "s_epochDuration",
  "s_ceoGracePeriod",
  "s_epochExecuted",
  "s_pendingPerformanceFeeUsdc",
]);

export function getFunctionArgTemplate(functionName: string): string {
  const fn = ceoVaultFunctionCatalog.find((item) => item.name === functionName);
  if (!fn || fn.inputs.length === 0) return "[]";
  return JSON.stringify(
    fn.inputs.map((input) => {
      if (input.type.endsWith("[]")) return [];
      if (input.type === "bool") return false;
      if (input.type === "string") return "";
      if (input.type === "bytes" || input.type.startsWith("bytes")) return "0x";
      if (input.type.startsWith("uint") || input.type.startsWith("int")) return "0";
      if (input.type === "address") return "0x0000000000000000000000000000000000000000";
      if (input.type.startsWith("tuple")) {
        return {
          target: "0x0000000000000000000000000000000000000000",
          value: "0",
          data: "0x",
        };
      }
      return "";
    }),
    null,
    2
  );
}
