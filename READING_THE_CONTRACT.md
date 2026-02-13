# READING_THE_CONTRACT

This guide explains how to read and analyze `contracts/src/CEOProtocol.sol` efficiently, with flow-by-flow context.

## 1) Start With The Mental Model

The contract has four interacting domains:

- **Vault staking (humans, MON):** users deposit/withdraw MON and hold shares.
- **Agent system ($CEO):** agents stake $CEO, register, vote, and compete for CEO.
- **Epoch governance/rebalance:** proposals and votes determine one executable rebalance per epoch.
- **Admin/security controls:** owner config, DEX controls, selector allowlist, timelocks, limits.

Read with this question in mind:  
**“Who can change value, when, and through which state transition?”**

---

## 2) Suggested Reading Order

1. **State variables** (top of file)
2. **Modifiers**
3. **Staking flow** (`deposit`, `withdraw`, `shareValue`)
4. **Agent lifecycle** (`registerAgent`, `deregisterAgent`, leaderboard helpers)
5. **Governance flow** (`registerProposal`, `vote`, proposal getters)
6. **Execution flow** (`executeRebalance`)
7. **Settlement flow** (`settleEpoch`, profitability, fee distribution)
8. **Admin controls**
9. **ERC-8004 integration**
10. **Receive hook**

---

## 3) State Layout: What Matters Most

### Vault/accounting core

- `s_totalShares`, `s_shares[user]`
- `s_totalAssets` (internal MON accounting)
- `s_vaultCap`

Interpretation:
- shares represent claims;
- `s_totalAssets` is the accounting base used for mint/burn math;
- **do not** assume `address(this).balance` equals withdrawable accounting value.

### Agent/governance core

- `s_agentList`, `s_agents`, `s_agentIndex`
- `s_currentEpoch`, `s_epochStartTime`, `s_epochRebalanced`
- `s_epochProposals`, `s_hasVoted`, `s_winningProposalId`

Interpretation:
- governance is epoch-scoped;
- one winning proposal per epoch may be executed.

### Rebalance security controls

- `s_whitelistedDex`
- `s_dexTimelockDelay`, `s_pendingDex`, `s_pendingDexTime`
- `s_maxSwapCalls`
- `s_allowedDexSelector`
- `s_inRebalance`

Interpretation:
- only one DEX target;
- dex address changes can be timelocked;
- low-level call surface is constrained by selector allowlist + max calls;
- receive path is guarded by rebalance context.

---

## 4) Core Flows And How To Analyze Them

## A. Human Deposit Flow

Path: `deposit()`

Checks:
- `msg.value > 0`
- `s_totalAssets + msg.value <= s_vaultCap`

Effects:
- compute shares:
  - first depositor: 1:1 shares
  - otherwise proportional to `s_totalAssets`
- update `s_shares`, `s_totalShares`, `s_totalAssets`

Analyze:
- rounding direction (small deposits can revert as `TooSmall`)
- cap behavior
- whether force-fed ETH can bias mint math (it should not)

## B. Human Withdraw Flow

Path: `redeem(sharesToBurn)`

Checks:
- non-zero and <= user shares

Effects:
- amount = proportional from `s_totalAssets`
- decrease user shares / total shares / total assets

Interaction:
- send ETH using `call`

Analyze:
- CEI order (state before external call)
- reentrancy protection
- consistency between `s_totalAssets` and ETH balance assumptions

## C. Agent Registration Flow

Path: `registerAgent(...)`

Checks:
- not already active
- `s_agentList.length < s_maxAgents`
- min CEO stake
- ERC-8004 identity configured + ownership checks

Effects:
- write agent struct, index mapping, list push

Interaction:
- pull `$CEO` from agent with `safeTransferFrom`

Analyze:
- loop bounds depend on max agent cap
- identity linkage assumptions

## D. Proposal + Vote Flow

Paths:
- `registerProposal(hash, uri)`
- `vote(proposalId, support)`

Checks:
- active agent + voting window
- proposal existence
- anti-double-vote mapping

Effects:
- append proposal
- weighted votes from current score (minimum 1)
- score side-effects for participation

Analyze:
- front-running and timing assumptions
- score inflation/drift behavior over epochs

## E. Rebalance Execution Flow (Most Sensitive)

Path: `executeRebalance(proposalId, swapCalls, minMonAfter)`

Execution gates:
- epoch not already rebalanced
- caller authorization:
  - CEO during grace period
  - second agent after grace period
- must be winning proposal
- `swapCalls.length <= s_maxSwapCalls`

Low-level call hardening:
- each call must have `length >= 4`
- selector extracted and checked in `s_allowedDexSelector`
- call goes only to `s_whitelistedDex` with `{value: 0}`

Accounting behavior:
- captures `monBeforeCalls`
- updates `s_totalAssets` only by positive in-tx MON delta
- avoids auto-accounting force-fed ETH present before execution

Analyze:
- selector allowlist coverage for intended DEX API
- timelock + confirmation process for DEX changes
- whether `minMonAfter` policy is strict enough for strategy

## F. Epoch Settlement Flow

Path: `settleEpoch()`

Responsibilities:
- validate settlement timing
- evaluate profitability (`itrn_measureProfitability`)
- update proposer/voter scores
- distribute `$CEO` rewards (if profitable)
- post ERC-8004 reputation (best-effort)
- advance epoch

Analyze:
- profitability heuristic limitations (not oracle-valued)
- loop complexity (`s_agentList`) now bounded by `s_maxAgents`
- reward distribution assumptions

---

## 5) Admin/Security Flow Map

### Ownership

- Start: `transferOwnership(newOwner)` -> sets `s_pendingOwner`
- Finish: `acceptOwnership()` by pending owner

### DEX change

- `setWhitelistedDex(newDex)`:
  - immediate if delay = 0
  - otherwise schedule pending
- `confirmWhitelistedDex()` after timelock

### Rebalance call surface controls

- `setMaxSwapCalls(max_)`
- `setDexSelectorAllowed(selector, allowed)`

### Loop safety control

- `setMaxAgents(max_)` (cannot drop below current count)

---

## 6) Quick Threat-Model Checklist While Reading

For each external/public function ask:

- **Who can call this?** (owner, agent, any user)
- **What is the worst state mutation possible?**
- **Any external call?** If yes, check CEI + reentrancy + revert handling.
- **Any loop?** Is it bounded?
- **Any low-level call?** Is calldata and target constrained?
- **Any accounting write?** Does it rely on internal tracked value or raw balance?

---

## 7) Practical “First 30 Minutes” Review Plan

1. Verify constructor config defaults (`dexTimelockDelay`, `maxSwapCalls`, `maxAgents`).
2. Validate owner-only setters cannot brick critical flows unintentionally.
3. Simulate one full epoch mentally:
   - deposit -> register agents -> proposal/vote -> execute -> settle -> withdraw.
4. Focus on `executeRebalance` and `settleEpoch` interactions.
5. Check that every state-changing critical path emits expected events.

---

## 8) Known Design Tradeoffs (Context)

- Profitability is heuristic (not oracle-valued).
- Rebalance call surface is constrained but still strategy-dependent.
- Blacklistable token behavior is documented; not fully solved at protocol level.

These are intentional design/roadmap decisions to keep in mind while auditing changes.
