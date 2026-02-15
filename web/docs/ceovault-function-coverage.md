# CEOVault Function Coverage Checklist

This checklist maps CEOVault external functions to either:

- Core UI (`/humans`, `/stats`, `/discuss`). Agent actions (register, vote, execute) via skill + OpenClaw or `/devtools`.
- Devtools (`/devtools`)

## Core UI

- `deposit`
- `mint`
- `withdraw`
- `redeem`
- `maxDeposit`
- `maxWithdraw`
- `maxRedeem`
- `previewDeposit`
- `previewWithdraw`
- `previewRedeem`
- `totalAssets`
- `balanceOf`
- `registerAgent`
- `deregisterAgent`
- `registerProposal`
- `vote`
- `execute`
- `convertPerformanceFee`
- `withdrawFees`
- `getClaimableFees`
- `getAgentInfo`
- `getAgentList`
- `getLeaderboard`
- `getProposalCount`
- `getProposal`
- `getTopAgent`
- `getSecondAgent`
- `isVotingOpen`
- `s_currentEpoch`
- `s_epochStartTime`
- `s_epochDuration`
- `s_ceoGracePeriod`
- `s_epochExecuted`
- `s_pendingPerformanceFeeUsdc`

## Devtools (remaining external surface)

- ERC20/share methods and views (`approve`, `transfer`, `transferFrom`, `allowance`, `name`, `symbol`, `totalSupply`, `decimals`)
- Owner/admin methods (`addYieldVault`, `removeYieldVault`, `setWhitelistedTarget`, `pause`, `unpause`, `recoverNative`, `transferOwnership`, `acceptOwnership`, all `set*`, `setERC8004Registries`)
- Maintenance/validation (`settleEpoch`, `requestRebalanceValidation`)
- Protocol/config/public getters and constants (`MAX_*`, `SCORE_*`, `s_*` mappings/getters, `getYieldVaults`, `getWinningProposal`, `getDeployedValue`, `asset`, `convertToAssets`, `convertToShares`, `maxMint`, `i_ceoToken`, `paused`)

## Validation Notes

- Coverage classification is rendered directly in `/devtools`.
- Function execution in Devtools uses CEOVault ABI metadata and JSON args parser.
- Core flows are implemented in persona routes and action modals with wagmi + viem writes.
