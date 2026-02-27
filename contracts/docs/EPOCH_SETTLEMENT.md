# Epoch Settlement Design (CEOVaultV2)

## Overview

CEOVaultV2 uses a simplified epoch settlement flow that removes the grace period and chains settlement into execution when a proposal is run.

## Two Settlement Paths

### Path A: Execute + Settle (chained)

When someone runs the winning proposal via `execute()`:

1. Voting has ended (`afterVoting`).
2. Caller runs `execute(proposalId, actions)`.
3. Actions are validated and executed.
4. **Settlement runs atomically** — `_settleEpoch()` is called at the end of `execute()`.
5. Profitability is measured, proposer/voters are scored, top 10 snapshot is taken, and the epoch advances.

**Result:** One transaction for execute + settle. No separate `settleEpoch()` call needed.

### Path B: Settle Only (no execution)

When no one executes (e.g. no proposals, or proposals exist but proposer is offline):

1. Voting has ended.
2. Anyone calls `settleEpoch()`.
3. The contract reverts with `AlreadyExecuted` if someone already executed (settlement was chained).
4. Otherwise, `_settleEpoch()` runs: profitability is measured (no proposal scoring since nothing was executed), top 10 snapshot is taken, epoch advances.

**Result:** Epoch advances so governance can continue. No proposal/proposer scoring when nothing was executed.

## Why No Grace Period?

Previously, a grace period delayed when `settleEpoch()` could be called, giving the executor time to run the winning proposal before settlement. With chained settlement:

- **Execute path:** Settlement happens immediately after execution — no delay needed.
- **No-execute path:** Settlement can happen as soon as voting ends — no reason to wait.

The grace period added complexity (config, tests, deploy params) without benefit.

## Summary

| Scenario                    | Action                    | Settlement                          |
|----------------------------|---------------------------|-------------------------------------|
| Proposals, someone executes | `execute()`               | Chained in same tx                  |
| Proposals, no one executes | `settleEpoch()`           | External call, no proposal scoring  |
| No proposals               | `settleEpoch()`            | External call, epoch advances       |
