# Draft: #2 Permissionless Execution, Simplified Rewards, CEO Token Utilization

This document describes proposed changes to **CEOVaultV2** for three governance and incentive improvements. The original CEOVault is not modified.

## Design Principles

1. **Execution should not be a bottleneck** — Anyone can execute the winning proposal after voting ends. Agent executors gain score points; non-agents get no reward.
2. **Agent rewards should be simple** — Entry fee flows directly to top 10 agents; the best agents attract more users, who pay entry fees, which reward agents.
3. **$CEO should have utility** — Staked $CEO increases voting power; optionally burn on vote. Reward share is rank-only (CEO staked not used).

---

## Part A: Permissionless Execution

**Problem:** Only the CEO (or #2 after grace period) can execute the winning proposal. This creates a bottleneck — if the CEO is offline or unreachable, the protocol stalls.

**Proposal:** Make execution permissionless. Anyone can call `execute()` after voting ends. Agent executors gain score points; non-agents get no reward.

### 1. Remove CEO-only restriction

**Current:** `execute()` calls `_requireExecutorOrCeo()`, which restricts execution to the top-ranked or second-ranked agent (after grace period).

**Change:** Remove `_requireExecutorOrCeo()` from `execute()`. Remove `getTopAgent()` and `getSecondAgent()` — no longer needed. Allow anyone to call after voting ends (after grace period). *(Note: `convertPerformanceFee` is removed with the performance fee.)*

### 2. Executor reward: points for agents only

**Logic:**

- On `execute()`: If `msg.sender` is an active agent, add score points (a new `PROPOSAL_EXECUTED, 1 point`).
- If `msg.sender` is **not** an agent: no rewards, no points. Anyone can still execute (permissionless), but only agents are incentivized via score.
- No token transfer — no USDC fee paid to executor. Keeps capital in the vault.

**Implementation:**

```solidity
// In execute(), after _markProposalExecuted(p):
if (s_agents[msg.sender].active) {
    s_agents[msg.sender].score += PROPOSAL_EXECUTED; 
}
```

**Event:**

```solidity
event Executed(uint256 indexed epoch, uint256 indexed proposalId, address indexed executor);
```

*Note: `Executed` already exists; add `executor` to the event if not present.*

### 3. CEO role: voting influence only

**Change:** CEO no longer has exclusive execution rights. CEO keeps scoring advantages (higher score, proposal wins, etc.) but **voting weight** can be boosted by staked $CEO (see Part C). Remove `SCORE_CEO_MISSED` 

---

## Part B: Simplified Agent Rewards (Entry Fee to Top 10)

**Problem:** Current flow: performance fee → USDC → swap to $CEO (via `convertPerformanceFee`) → distribute to top 10. Too many steps, dependencies on DEX, slippage.

**Proposal:** Remove performance fee entirely. Entry fee is the **only** agent reward. Route entry fee to top 10 agents. Entry fee USDC is swapped to $CEO (e.g. by treasury or keeper) and distributed; agents claim $CEO via `claimFees()`.

### 1. Entry fee recipient options

**Current:** `_entryFeeRecipient()` returns `s_treasury`. Entry fee goes to treasury.

**Change:** Add configurable recipient:

```solidity
/// @notice Where entry fee goes: 0 = treasury (legacy), address(this) = vault (distribute to agents)
address public s_entryFeeRecipient;
```

- `s_entryFeeRecipient == s_treasury` (or default): Same as today — fee goes to treasury.
- `s_entryFeeRecipient == address(this)`: Fee stays in vault; `_deposit` calls `_distributeEntryFeeToAgents(fee)`.

### 2. Distribute entry fee to top 10 agents

**New internal function:**

```solidity
/// @dev Distribute entry fee USDC to top 10 agents. Called from _deposit when s_entryFeeRecipient == address(this).
/// @param amount Amount of USDC (asset) to distribute
function _distributeEntryFeeToAgents(uint256 amount) internal {
    if (amount == 0) return;

    address[10] memory topAgents;
    uint256[10] memory weights;  // voting weights or shares
    uint256 topCount;
    uint256 totalWeight;

    // Get top 10 agents by score (same logic as _distributeFees for $CEO)
    // ... populate topAgents, weights, totalWeight ...

    if (totalWeight == 0) return;

    for (uint256 i = 0; i < topCount; i++) {
        uint256 share = amount * weights[i] / totalWeight;
        if (share > 0) {
            s_claimableFees[topAgents[i]] += share;
        }
    }

    // USDC stays in vault; claimableFees are withdrawn via claimFees()
}
```

**Claim flow:** Agents claim USDC via `withdrawFees()`. Entry fee stays in vault; `s_claimableFees` tracks USDC amounts per agent. *Future enhancement:* $CEO payout (swap USDC→$CEO via treasury/keeper or vault-integrated swap; agents claim $CEO via `claimFees()`) will be implemented in a later version.

### 3. Distribution: rank-based weights (CEO staked not used)

**Distribution logic:** `weights[i] = 10 - i` (rank 1 gets 10, rank 2 gets 9, ..., rank 10 gets 1). Normalize to total. CEO staked is **not** used for reward share — distribution is purely rank-based.

```solidity
// For each of top 10 agents: weight = 10 - rank (1-indexed)
// totalWeight = 10+9+8+7+6+5+4+3+2+1 = 55 (or compute dynamically for topCount < 10)
for (uint256 i = 0; i < topCount; i++) {
    weights[i] = 10 - i;  // rank 1 (i=0) -> 10, rank 2 (i=1) -> 9, ...
}
totalWeight = sum(weights);  // e.g. 55 for 10 agents
```

### 4. Owner configuration

```solidity
/// @notice Set entry fee recipient. address(this) = distribute to agents; else = treasury.
function setEntryFeeRecipient(address recipient) external onlyOwner {
    s_entryFeeRecipient = recipient;
    emit EntryFeeRecipientSet(recipient);
}
```

### 5. Modify `_deposit` / `_entryFeeRecipient`

**Override `_entryFeeRecipient()`:**

```solidity
function _entryFeeRecipient() internal view virtual override returns (address) {
    return s_entryFeeRecipient != address(0) ? s_entryFeeRecipient : s_treasury;
}
```

**Override `_deposit`:** When `recipient == address(this)`, don't transfer fee out — instead call `_distributeEntryFeeToAgents(fee)`. The fee stays in vault; `s_claimableFees` tracks who gets what. Agents claim via `claimFees()`.

**ERC4626Fees behavior:** `_deposit` checks `recipient != address(this)` before transferring. If `recipient == address(this)`, the fee is already in the vault (caller deposits to vault, fee portion stays). So we need to either:
- Not call `super._deposit` with the fee portion — we keep it in vault and distribute to agents.
- Or: `_entryFeeRecipient() == address(this)` means the fee is "sent" to the vault (it stays in vault). Then in our override we call `_distributeEntryFeeToAgents(fee)` to allocate shares to agents.

---

## Part C: CEO Token Utilization

**Problem:** Staked $CEO sits in the contract with no utility beyond registration eligibility.

**Proposal:** Use $CEO for (1) voting power multiplier, (2) reward multiplier, (3) optional burn on vote.

### 1. Voting weight: include staked $CEO

**Voting model: value-based, not count-based.** Each proposal has `votesFor` and `votesAgainst` as **sums of agent weights** (values), not voter counts. When an agent votes, their `weight` is added to the chosen side. The winning proposal is the one with the highest **net value** (`votesFor - votesAgainst`), not the most voters.

**Current:** `weight = max(1, score)` (absolute score).

**Change:**

```solidity
/// @notice Voting weight multiplier for staked $CEO (e.g. 1e18 = 1:1, 2e18 = 2x stake = 2x weight)
uint256 public s_ceoStakeVotingMultiplier;

uint256 weight = _getVotingWeight(msg.sender);
```

```solidity
function _getVotingWeight(address agent) internal view returns (uint256) {
    Agent storage a = s_agents[agent];
    if (!a.active) return 0;
    uint256 baseWeight = a.score > 0 ? uint256(a.score) : 1;
    uint256 stakeBonus = a.ceoStaked * s_ceoStakeVotingMultiplier / 1e18;
    return baseWeight + stakeBonus;
}
```

So: `weight = baseScore + (ceoStaked * multiplier / 1e18)`. CEO with more stake has more influence.

**Whale mitigation:** To prevent one agent from buying control by staking large amounts of $CEO, use **diminishing returns** on stake instead of linear. E.g. `stakeBonus = sqrt(ceoStaked) * multiplier` — doubling stake increases weight by ~1.4×, not 2×.

```solidity
// Diminishing returns: stakeBonus from sqrt(ceoStaked)
uint256 stakeBonus = Math.sqrt(a.ceoStaked * 1e18) * s_ceoStakeVotingMultiplier / 1e18;
return baseWeight + stakeBonus;
```

Example: Agent A stakes 10,000 $CEO → sqrt(10000)=100; Agent B stakes 1,000,000 $CEO → sqrt(1e6)=1000. B has 100× the stake but only ~10× the stake-derived weight (vs 100× with linear). Makes it much harder to buy dominance.

### 2. Reward share: rank-only (CEO staked not used)

**Current:** Top 10 get rank-weighted split (rank 1=10, rank 2=9, ..., rank 10=1).

**Change:** CEO staked is **not** used for reward share. Distribution remains purely rank-based: `weights[i] = 10 - i`. This keeps rewards simple and avoids stake concentration effects.

### 3. Optional: burn $CEO on vote

**Idea:** Each vote burns a small amount of staked $CEO (e.g. `ceoStaked * 1 / 10000`). This creates deflationary pressure and ties commitment to voting.

```solidity
// In vote():
uint256 burnAmount = agent.ceoStaked / 10000;  // 0.01% per vote
if (burnAmount > 0) {
    agent.ceoStaked -= burnAmount;
    IERC20(i_ceoToken).transfer(address(0xdead), burnAmount);  // or use a burn function
}
```

**Risks:** Agents may vote less to avoid burning. Consider making it optional or very small.

---

## Part D: Summary of Changes

| Area | Change |
|------|--------|
| **Execution** | Remove `_requireExecutorOrCeo` from `execute()`; allow anyone after grace period |
| **Executor reward** | If executor is an agent: add score points (e.g. `PROPOSAL_EXECUTED`). If not an agent: no rewards, no points |
| **Performance fee** | Remove entirely (no `convertPerformanceFee`, no `s_pendingPerformanceFeeUsdc` accrual) |
| **Entry fee** | Add `s_entryFeeRecipient`; when `address(this)`, distribute entry fee to top 10 agents (weights: rank 1=10, rank 2=9, ..., rank 10=1) |
| **Claim** | Agent `withdrawFees()` pays USDC. *Future:* `claimFees()` will pay $CEO (swap done by treasury/keeper or vault-integrated) |
| **Voting weight** | Value-based: `votesFor`/`votesAgainst` = sums of weights; winner = highest net value. `weight = baseScore + sqrt(ceoStaked) * multiplier` (diminishing returns) |
| **Reward share** | Top 10 distribution weighted by rank only: weights 10, 9, 8, ..., 1 (CEO staked not used) |
| **Burn on vote** | Optional: burn `ceoStaked / 10000` per vote |

---

## Part E: Files to Modify

| File | Action |
|------|--------|
| `ICEOVaultV2.sol` | Add `s_entryFeeRecipient`, `s_ceoStakeVotingMultiplier`; add `EntryFeeRecipientSet` |
| `CEOVaultV2.sol` | Remove performance fee (convertPerformanceFee, s_pendingPerformanceFeeUsdc); remove `_requireExecutorOrCeo`, `getTopAgent`, `getSecondAgent` from `execute`; add executor score for agents only; add `_distributeEntryFeeToAgents` with rank-only `_computeRankedShares`; override `_entryFeeRecipient`; add `_getVotingWeight`; modify `vote()` to use new weight; add `setEntryFeeRecipient`, `setCeoStakeVotingMultiplier` |

---

## Part F: Migration / Compatibility

- **Entry fee:** If `s_entryFeeRecipient == address(0)`, default to `s_treasury` (backward compatible).
- **Voting weight:** Default `s_ceoStakeVotingMultiplier = 0`; then `weight = baseScore` (current behavior).

---

## Part G: Open Questions / Future Enhancements

1. **Entry fee → $CEO swap:** Who triggers the swap? Treasury, keeper, or vault-integrated swap (e.g. nad.fun)? When: on each deposit, or batched periodically? *Planned for a future version:* agents will claim $CEO via `claimFees()` instead of USDC via `withdrawFees()`.
2. **Burn on vote:** Include or leave as optional future enhancement?
3. **Epoch 1 fee distribution:** During epoch 1, no top 10 snapshot exists yet. Entry fees (when recipient is `address(this)`) are sent to treasury instead of being distributed to agents.
