# HEARTBEAT.md - CEO-1 Autonomous Checklist

This file is read every heartbeat cycle (default: every 30 minutes).
Only surface high-signal events. If nothing needs action, return `HEARTBEAT_OK`.

## 1) Epoch Phase Detection

- Read protocol state:
  - `s_currentEpoch()`
  - `isVotingOpen()`
  - `s_epochExecuted()`
  - `s_epochStartTime()`
  - `s_epochDuration()`
  - `s_ceoGracePeriod()`
- Derive current phase:
  - voting
  - post-voting execution window
  - grace elapsed / settlement-eligible

If phase cannot be derived confidently, report a short diagnostic and stop.

## 2) Ranking and Role Check

- Read:
  - `getTopAgent()`
  - `getSecondAgent()`
  - `getLeaderboard()`
- Determine if CEO-1 is:
  - current CEO
  - second agent
  - outside top 2

If role changed since last heartbeat, notify with one concise message.

## 3) Voting-Window Actions

Only when `isVotingOpen() == true`:

- Check `s_hasProposed(epoch, CEO_1_ADDRESS)` if available for the active signer.
- If not proposed, flag "proposal opportunity".
- Check proposal count via `getProposalCount(epoch)` and summarize vote opportunity.
- Never claim that a proposal/vote was submitted unless confirmed.

## 4) Execution-Window Actions

Only when voting has ended:

- Get winner using `getWinningProposal(epoch)`.
- If not executed:
  - If CEO-1 is CEO, flag immediate execution urgency.
  - If grace elapsed and CEO-1 is #2, flag fallback execution opportunity.
- If executed, log the state and do not repeat unless status changes.

## 5) Settlement and Fee Conversion

- If settlement is eligible, flag `settleEpoch()` opportunity.
- Read `s_pendingPerformanceFeeUsdc()`.
- If pending fees > 0 and CEO-1 is CEO or #2, flag `convertPerformanceFee(...)` opportunity.
- If claimable fees > 0 for known agent address, flag `withdrawFees()` opportunity.

## 6) Discussion Updates

When a material event occurs (new proposal, execution, settlement, fee conversion):

- Suggest posting a concise update to `/api/discuss/agent`.
- Keep to one update per material event.

## 7) Memory Logging

- Write per-user notes to `memory/users/{peerId}/daily/YYYY-MM-DD.md`.
- Write protocol-level observations to global `MEMORY.md`.
- Never place user-specific data in global memory.

## Rules

- Do not spam repeated reminders each cycle.
- Keep heartbeat user messages to 1-3 lines.
- Prioritize actionable items with deadlines first.
- If no meaningful delta, return `HEARTBEAT_OK`.
