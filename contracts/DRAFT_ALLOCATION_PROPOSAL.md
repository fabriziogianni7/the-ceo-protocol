# Draft: #1 Percentage-Based Allocation Proposals (Deployed Capital)

This document describes the implementation for **CEOVaultV2** only. The original CEOVault is not modified.

## Design Principle

**Capital should not sit idle.** Proposals regard the **current deployed capital** (total AUM across yield vaults + idle) and specify **target allocation percentages**. Execution performs a **rebalance**: withdraw from overweight vaults, deposit into underweight vaults. Proposals never go stale because they use percentages, not fixed amounts.

---

## Part A: Interface Changes (`ICEOVault.sol`)

*Note: Create `ICEOVaultV2.sol` or extend the interface used by CEOVaultV2.*

### 1. New struct

```solidity
/// @notice Target allocation for a yield vault (basis points of total AUM, e.g. 5000 = 50%)
struct AllocationTarget {
    address vault;   // ERC4626 yield vault (must be in s_yieldVaults)
    uint256 bps;     // Basis points of totalAssets() to allocate here
}
```

### 2. Extend Proposal struct

```solidity
struct Proposal {
    bytes32 proposalHash;
    string proposalURI;
    address proposer;
    uint256 votesFor;
    uint256 votesAgainst;
    uint256 epoch;
    bool executed;
    bool settled;
    bool isAllocation;  // true = allocation proposal (executeAllocation), false = action proposal (execute)
}
```

### 3. New errors

```solidity
error AllocationBpsExceedMax();
error InvalidAllocationVault();
error InvalidAllocationCount();
error NotAllocationProposal();
error UseExecuteAllocationForAllocationProposal();
```

### 4. New event

```solidity
event AllocationProposalRegistered(
    uint256 indexed epoch, uint256 indexed proposalId, bytes32 allocationHash, address proposer
);
```

---

## Part B: CEOVaultV2 Contract Changes

### 1. New constant

```solidity
uint256 public constant MAX_ALLOCATION_TARGETS = 10;
```

### 2. New internal helper: `_getValueInVault`

```solidity
/// @dev Get the asset value currently deployed in a specific yield vault
function _getValueInVault(address vault) internal view returns (uint256) {
    uint256 shares = IERC20(vault).balanceOf(address(this));
    if (shares == 0) return 0;
    try IERC4626(vault).convertToAssets(shares) returns (uint256 assets) {
        return assets;
    } catch {
        return 0;
    }
}
```

### 3. New function: `registerProposalAllocation`

```solidity
/// @notice Submit an allocation-based proposal (target % of total AUM per vault)
/// @dev Allocations specify target percentages of totalAssets(). Sum of bps must be <= 10_000.
///      At execution, the contract rebalances: withdraws from overweight vaults, deposits into underweight.
///      Proposals never go stale — amounts are resolved at execution time from current deployed capital.
/// @param allocations Array of { vault, bps } — e.g. [{vaultA, 5000}, {vaultB, 5000}] = 50/50 split
/// @param proposalURI Off-chain URI with proposal details
function registerProposalAllocation(AllocationTarget[] calldata allocations, string calldata proposalURI)
    external
    whenNotPaused
    onlyActiveAgent
    duringVoting
    nonReentrant
{
    if (allocations.length == 0 || allocations.length > MAX_ALLOCATION_TARGETS) revert InvalidAllocationCount();
    if (s_hasProposed[s_currentEpoch][msg.sender]) revert AlreadyProposed();
    if (s_epochProposals[s_currentEpoch].length >= MAX_PROPOSALS_PER_EPOCH) revert MaxProposalsReached();

    uint256 totalBps;
    for (uint256 i = 0; i < allocations.length; i++) {
        if (!s_isYieldVault[allocations[i].vault]) revert InvalidAllocationVault();
        totalBps += allocations[i].bps;
    }
    if (totalBps > 10_000) revert AllocationBpsExceedMax();

    bytes32 allocationHash = keccak256(abi.encode(allocations));

    s_hasProposed[s_currentEpoch][msg.sender] = true;

    uint256 proposalId = s_epochProposals[s_currentEpoch].length;
    s_epochProposals[s_currentEpoch].push(
        Proposal({
            proposalHash: allocationHash,
            proposalURI: proposalURI,
            proposer: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            epoch: s_currentEpoch,
            executed: false,
            settled: false,
            isAllocation: true
        })
    );

    s_agents[msg.sender].score += SCORE_PROPOSAL_SUBMITTED;

    emit AllocationProposalRegistered(s_currentEpoch, proposalId, allocationHash, msg.sender);
}
```

### 4. New function: `executeAllocation`

Rebalances deployed capital to match the target allocation. Uses **totalAssets()** as the total (includes idle + deployed). For each vault in the allocation: `targetAmount = totalAssets() * bps / 10_000`. For vaults not in the allocation: target = 0 (withdraw all). Execution order: withdraw first, then deposit.

```solidity
/// @notice Execute the winning allocation proposal by rebalancing deployed capital
/// @dev Rebalances so each vault holds targetAmount = totalAssets() * bps / 10_000.
///      Vaults not in the allocation are fully withdrawn. Withdraws first, then deposits.
/// @param proposalId Index of the winning proposal
/// @param allocations Must match the proposal's committed allocationHash
function executeAllocation(uint256 proposalId, AllocationTarget[] calldata allocations)
    external
    whenNotPaused
    afterVoting
    nonReentrant
{
    if (s_epochExecuted) revert AlreadyExecuted();
    if (allocations.length == 0 || allocations.length > MAX_ALLOCATION_TARGETS) revert InvalidAllocationCount();

    // Access control: same as execute
    address ceo = getTopAgent();
    if (msg.sender != ceo) {
        if (block.timestamp < s_epochStartTime + s_epochDuration + s_ceoGracePeriod) {
            revert GracePeriodOnlyCeo();
        }
        address second = getSecondAgent();
        if (second != address(0) && msg.sender != second) revert OnlyCeoOrSecond();
        if (ceo != address(0)) {
            s_agents[ceo].score += SCORE_CEO_MISSED;
        }
    }

    uint256 numProposals = s_epochProposals[s_currentEpoch].length;
    if (numProposals == 0) revert NoProposals();
    if (proposalId >= numProposals) revert InvalidProposal();

    Proposal storage p = s_epochProposals[s_currentEpoch][proposalId];
    if (!p.isAllocation) revert NotAllocationProposal();
    if (p.executed) revert AlreadyExecuted();
    if (keccak256(abi.encode(allocations)) != p.proposalHash) revert ActionsMismatch();

    uint256 totalBps;
    for (uint256 i = 0; i < allocations.length; i++) {
        if (!s_isYieldVault[allocations[i].vault]) revert InvalidAllocationVault();
        totalBps += allocations[i].bps;
    }
    if (totalBps > 10_000) revert AllocationBpsExceedMax();

    uint256 totalBefore = totalAssets();
    uint256 totalValue = totalBefore;

    // Build target amounts for allocated vaults
    mapping(address => uint256) targetAmounts;  // Solidity: use a struct or inline logic
    for (uint256 i = 0; i < allocations.length; i++) {
        targetAmounts[allocations[i].vault] = totalValue * allocations[i].bps / 10_000;
    }

    // PHASE 1: Withdraw from vaults that are overweight (current > target)
    // Vaults not in allocation have target = 0
    uint256 len = s_yieldVaults.length;
    for (uint256 i = 0; i < len; i++) {
        address vault = s_yieldVaults[i];
        uint256 current = _getValueInVault(vault);
        uint256 target = targetAmounts[vault];  // 0 if not in allocation
        if (current > target) {
            uint256 toWithdraw = current - target;
            if (toWithdraw > 0) {
                try IERC4626(vault).withdraw(toWithdraw, address(this), address(this)) {
                    // Success
                } catch {
                    revert ActionFailed();
                }
            }
        }
    }

    // PHASE 2: Deposit into vaults that are underweight (target > current)
    for (uint256 i = 0; i < allocations.length; i++) {
        address vault = allocations[i].vault;
        uint256 target = totalValue * allocations[i].bps / 10_000;
        uint256 current = _getValueInVault(vault);
        if (target > current) {
            uint256 toDeposit = target - current;
            if (toDeposit > 0) {
                IERC20(asset()).forceApprove(vault, toDeposit);
                try IERC4626(vault).deposit(toDeposit, address(this)) {
                    // Success
                } catch {
                    IERC20(asset()).forceApprove(vault, 0);
                    revert ActionFailed();
                }
                IERC20(asset()).forceApprove(vault, 0);
            }
        }
    }

    p.executed = true;
    s_epochExecuted = true;
    s_agents[p.proposer].score += SCORE_PROPOSAL_WON;

    if (s_maxDrawdownBps > 0 && totalBefore > 0) {
        uint256 totalAfter = totalAssets();
        uint256 minAllowed = totalBefore * (10_000 - s_maxDrawdownBps) / 10_000;
        if (totalAfter < minAllowed) revert ExcessiveDrawdown();
    }

    emit Executed(s_currentEpoch, proposalId, msg.sender);
}
```

**Note on `mapping` in function:** Solidity does not allow `mapping` as a local variable. Use one of:
- A temporary `address[]` + loop to find target, or
- An internal helper that takes `(vault, allocations)` and returns target for that vault.

**Simplified execution logic (no local mapping):**

```solidity
// PHASE 1: Withdraw from all yield vaults that are overweight
for (uint256 i = 0; i < s_yieldVaults.length; i++) {
    address vault = s_yieldVaults[i];
    uint256 current = _getValueInVault(vault);
    uint256 target = _getTargetForVault(vault, allocations, totalValue);
    if (current > target) {
        uint256 toWithdraw = current - target;
        if (toWithdraw > 0) {
            IERC4626(vault).withdraw(toWithdraw, address(this), address(this));
        }
    }
}

// PHASE 2: Deposit into allocated vaults that are underweight
for (uint256 i = 0; i < allocations.length; i++) {
    address vault = allocations[i].vault;
    uint256 target = totalValue * allocations[i].bps / 10_000;
    uint256 current = _getValueInVault(vault);
    if (target > current) {
        uint256 toDeposit = target - current;
        if (toDeposit > 0) {
            IERC20(asset()).forceApprove(vault, toDeposit);
            IERC4626(vault).deposit(toDeposit, address(this));
            IERC20(asset()).forceApprove(vault, 0);
        }
    }
}
```

Helper:
```solidity
function _getTargetForVault(address vault, AllocationTarget[] calldata allocations, uint256 totalValue)
    internal
    pure
    returns (uint256)
{
    for (uint256 i = 0; i < allocations.length; i++) {
        if (allocations[i].vault == vault) {
            return totalValue * allocations[i].bps / 10_000;
        }
    }
    return 0; // Not in allocation -> withdraw all
}
```

### 5. Modify `registerProposal`

Add `isAllocation: false` when pushing a new Proposal.

### 6. Modify `execute`

After loading the proposal, add:
```solidity
if (p.isAllocation) revert UseExecuteAllocationForAllocationProposal();
```

### 7. New view: `getWinningProposalIsAllocation`

```solidity
function getWinningProposalIsAllocation(uint256 epoch) external view returns (bool) {
    (uint256 winnerId,) = getWinningProposal(epoch);
    return s_epochProposals[epoch][winnerId].isAllocation;
}
```

---

## Part C: Execution Flow Summary

1. **Total value** = `totalAssets()` (idle + deployed - pending fees)
2. **Target per vault** = `totalValue * bps / 10_000` for vaults in allocation; 0 for others
3. **Phase 1:** For each yield vault, if `current > target`, withdraw `(current - target)`
4. **Phase 2:** For each vault in allocation, if `target > current`, deposit `(target - current)`

This rebalances deployed capital to match the proposal. If there is idle USDC, it is treated as part of total AUM; allocations with `sum(bps) < 10_000` leave the remainder idle.

---

## Part D: Approvable Tokens List

To support strategies like "deposit vault shares into another vault" or "supply vault shares to Uniswap LP", action-based proposals need to approve tokens beyond USDC and $CEO. An **approvable tokens** list allows `approve(token, spender, amount)` for any token in the list, as long as `spender` is whitelisted.

### Design

- **State:** `mapping(address => bool) public s_isApprovableToken`
- **Rule:** `approve()` is allowed when `target` is `asset()`, `i_ceoToken`, or `s_isApprovableToken[target] == true`, and `spender` is whitelisted.
- **Updates:** The list can be updated by:
  1. **Contract owner** — direct admin calls
  2. **Proposal execution** — a winning proposal can include an action that adds/removes tokens (governance-driven)

### Owner Functions

```solidity
/// @notice Add a token to the approvable list (owner only)
function addApprovableToken(address token) external onlyOwner {
    if (token == address(0)) revert ZeroAddress();
    if (s_isApprovableToken[token]) return; // idempotent
    s_isApprovableToken[token] = true;
    emit ApprovableTokenAdded(token);
}

/// @notice Remove a token from the approvable list (owner only)
function removeApprovableToken(address token) external onlyOwner {
    if (!s_isApprovableToken[token]) return; // idempotent
    s_isApprovableToken[token] = false;
    emit ApprovableTokenRemoved(token);
}
```

### Governance: Proposal-Driven Updates

A winning action-based proposal can update the approvable list by including a self-call:

- **Action:** `target: address(this)`, `data: addApprovableToken(token)` or `removeApprovableToken(token)`

**Validation rule (extend `_validateAction`):** Add Rule 5 for self-calls. Check this *before* Rule 4 (whitelisted targets). If `target == address(this)`:
- Allow `addApprovableToken(address token)` — token must not be `address(0)`; `asset()` and `i_ceoToken` are always approvable, so adding them is redundant but harmless
- Allow `removeApprovableToken(address token)` — token must be in `s_isApprovableToken` (cannot remove core tokens from the list; they are implicitly always allowed)

```solidity
// ── Rule 5: Self-calls for governance (add/remove approvable tokens) ──
if (target == address(this)) {
    if (data.length < 36) return false;
    bytes4 selector = bytes4(data[:4]);
    if (selector == this.addApprovableToken.selector) {
        address token = abi.decode(data[4:36], (address));
        return token != address(0);
    }
    if (selector == this.removeApprovableToken.selector) {
        address token = abi.decode(data[4:36], (address));
        return s_isApprovableToken[token]; // can only remove tokens that were added
    }
    return false; // no other self-calls allowed
}
```

**Execution:** When processing actions, if the target is `address(this)`, the vault executes the call on itself. This allows governance to expand the set of tokens agents can use in future strategies (e.g. add moUSDC so the next epoch's proposal can approve it to Uniswap).

### New Errors & Events

```solidity
error TokenNotApprovable();
error CannotRemoveCoreToken();  // if trying to remove asset() or i_ceoToken from "always allowed" (N/A if we never add them to the list)

event ApprovableTokenAdded(address indexed token);
event ApprovableTokenRemoved(address indexed token);
```

### Modify `_validateAction` (Rule 2)

```solidity
// ── Rule 2: Token contracts — approve only, spender must be whitelisted ──
// Allowed tokens: asset(), i_ceoToken, or s_isApprovableToken[target]
if (target == asset() || target == address(i_ceoToken) || s_isApprovableToken[target]) {
    if (data.length < 68) return false;
    bytes4 selector = bytes4(data[:4]);
    if (selector != IERC20.approve.selector) return false;
    address spender = abi.decode(data[4:68], (address));
    return s_isWhitelistedTarget[spender];
}
```

### Modify `_revokeTokenApprovals`

Extend to revoke approvals for all tokens used in approve actions, not just `asset()` and `i_ceoToken`. Iterate over actions; for any `approve(token, spender, amount)` where `token` is asset, ceoToken, or in approvable list, revoke after execution.

### Summary

| Updater | Method |
|---------|--------|
| Owner | `addApprovableToken(token)`, `removeApprovableToken(token)` |
| Governance | Include `addApprovableToken` / `removeApprovableToken` as an action in a winning proposal |

This enables strategies such as: deposit USDC → vault shares → approve shares → supply to Uniswap LP, once the vault share token (e.g. moUSDC) is added to the approvable list by the owner or by a prior governance proposal.

---

## Part E: Simulation Functions (Pre-Submit Validation)

External functions that agents can call **before submitting** a proposal to validate and simulate the outcome. Callable by anyone (no auth required).

### 1. `simulateActions` (revert-at-end)

Action-based proposals require **execution simulation** — the actions call external contracts. Use a **revert-at-end** pattern: run the full execution, then revert. When called via `eth_call`, the entire tx is rolled back, so no state persists.

```solidity
/// @notice Simulate action-based proposal execution
/// @dev Call via eth_call (staticcall). Runs validation + execution, then reverts with SimulationSuccess.
///      If any action fails, reverts with SimulationFailed(index). State is rolled back when used as eth_call.
/// @param actions The actions to simulate
function simulateActions(Action[] calldata actions) external
```

**Logic:**
1. Validate all actions (same as `execute`)
2. For each action: `(bool ok,) = action.target.call(action.data)`; if `!ok`, revert with `SimulationFailed(actionIndex)`
3. Revoke any approvals set during execution
4. Revert with `SimulationSuccess()` — caller interprets this as "simulation passed"

**Usage:** Agent calls `simulateActions(actions)` via `eth_call`. If the call reverts with `SimulationSuccess`, the proposal is valid and would execute. If it reverts with `SimulationFailed(i)`, action `i` failed.

### 2. New errors

```solidity
error SimulationFailed(uint256 actionIndex);
error SimulationSuccess();  // Reverted intentionally at end of successful simulation — caller checks for this via eth_call
```

### 3. Optional: `validateActions` (view, validation-only)

For a lighter check without execution simulation:

```solidity
/// @notice Validate actions without executing. Returns true if all actions pass _validateAction.
function validateActions(Action[] calldata actions) external view returns (bool valid);
```

This catches invalid targets, wrong selectors, bad params — but does not catch runtime failures (e.g. insufficient balance, slippage).

### Summary

| Function | Type | Use case |
|----------|------|----------|
| `simulateActions(actions)` | state-changing (revert-at-end) | Pre-submit: full execution simulation via `eth_call`; reverts with `SimulationSuccess` if valid |
| `validateActions(actions)` | view | Pre-submit: quick validation check only |

---

## Part F: Files to Create/Modify (CEOVaultV2 only)

| File | Action |
|------|--------|
| `ICEOVault.sol` or `ICEOVaultV2.sol` | Add `AllocationTarget`, new errors, new event; add approvable token events |
| `CEOVaultV2.sol` | Add `executeRebalance` (self-call), `registerProposal(actions, uri)`, `execute(proposalId, actions)`; add `_getValueInVault`, `_getTargetForVault`, `_validateAllocations`; add `s_isApprovableToken`, value adapters, selector whitelist; add `simulateActions`, `validateActions`; modify `_validateAction` (Rule 5: add executeRebalance) |
| `IValueAdapter.sol` | New interface for value adapters (Part H) |

**CEOVault.sol (original) is not modified.**

---

## Part G: Mixed Ordered List (Rebalance as Action)

Proposals use a **single ordered list of actions**. Rebalance is a normal action (self-call), enabling flexible ordering: withdraw from lending → rebalance vaults → deposit in DEX.

### Design

1. **Single proposal type** — Only `actions`. No separate `allocations` parameter.
2. **Rebalance as action** — Rebalance is invoked via `target: address(this)`, `data: executeRebalance(allocations)`.
3. **Ordering** — Agent controls exact sequence. Example: [withdraw from lending, rebalance vaults, deposit in DEX].
4. **Proposal hash** — `keccak256(abi.encode(actions))` commits the full ordered list.

### API

```solidity
registerProposal(actions, proposalURI)
execute(proposalId, actions)
```

### Rebalance Action Format

```solidity
Action {
    target: address(this),
    value: 0,
    data: abi.encodeWithSelector(CEOVaultV2.executeRebalance.selector, allocations)
}
```

### Self-Call: `executeRebalance`

- **Function:** `executeRebalance(AllocationTarget[] calldata allocations)` — callable only by `address(this)`.
- **Logic:** Same as current allocation phase — withdraw from overweight yield vaults, deposit into underweight.
- **Rule 5:** When `target == address(this)` and selector is `executeRebalance`, decode allocations and validate (vaults in `s_yieldVaults`, `sum(bps) <= 10_000`).

### Example Ordered List

```
Action 1: Withdraw 50 USDC from lending
  target: lendingProtocol, data: withdraw(50e6)

Action 2: Rebalance 40% vault A, 40% vault B (20% left idle for next step)
  target: address(this)
  data: executeRebalance([{vault: A, bps: 4000}, {vault: B, bps: 4000}])

Action 3: Deposit 20 USDC in DEX
  target: dexAdapter, data: addLiquidity(20e6)
```

### Simulation

- **`simulateActions(actions)`** — Runs full execution (including `executeRebalance` actions) then reverts with `SimulationComplete`. Use before proposing.
- **`validateActions(actions)`** — Validates all actions (including `executeRebalance`).

---

## Part H: Protocol Registry with Value Adapters

To include capital deployed in lending, DEX, and other non-ERC4626 protocols in `totalAssets()`, the vault maintains a **value adapter registry**. Each adapter reports the vault's USDC-denominated value in that protocol.

### Interface

```solidity
interface IValueAdapter {
    /// @notice Return USDC-denominated value of the vault's position in this protocol
    /// @param vault The CEOVault address
    /// @return value Value in asset decimals (e.g. USDC 6 decimals)
    function getDeployedValue(address vault) external view returns (uint256 value);
}
```

### State

```solidity
address[] public s_valueAdapters;
mapping(address => bool) public s_isValueAdapter;
uint256 public constant MAX_VALUE_ADAPTERS = 20;
```

### Owner Functions

```solidity
/// @notice Add a value adapter for protocols (lending, DEX, etc.) where vault has deployed capital
function addValueAdapter(address adapter) external onlyOwner;

/// @notice Remove a value adapter
function removeValueAdapter(address adapter) external onlyOwner;
```

### Modify `_deployedValue()`

```solidity
function _deployedValue() internal view returns (uint256 value) {
    // 1. Yield vaults (ERC4626)
    for (uint256 i = 0; i < s_yieldVaults.length; i++) {
        address vault = s_yieldVaults[i];
        uint256 shares = IERC20(vault).balanceOf(address(this));
        if (shares > 0) {
            try IERC4626(vault).convertToAssets(shares) returns (uint256 assets) {
                value += assets;
            } catch {}
        }
    }
    // 2. Value adapters (lending, DEX, etc.)
    for (uint256 i = 0; i < s_valueAdapters.length; i++) {
        try IValueAdapter(s_valueAdapters[i]).getDeployedValue(address(this)) returns (uint256 v) {
            value += v;
        } catch {}
    }
}
```

### Errors & Events

```solidity
error ValueAdapterAlreadyAdded();
error ValueAdapterNotFound();
event ValueAdapterAdded(address indexed adapter);
event ValueAdapterRemoved(address indexed adapter);
```

### Example Adapters

- **CTokenValueAdapter**: Compound-style cTokens — `balanceOf(vault) * exchangeRateCurrent() / 1e(8+decimals)`
- **ATokenValueAdapter**: Aave aTokens — `balanceOf(vault)` (1:1 with underlying)
- **ERC4626ValueAdapter**: Generic ERC4626 — `convertToAssets(balanceOf(vault))`

---

## Part I: Selector Whitelist per Target

Whitelisted targets (adapters, lending protocols, DEX) are restricted to **allowed function selectors**. This limits the attack surface when a protocol is buggy or malicious.

### Design

- **Yield vaults** (Rule 3): No selector whitelist — they only allow ERC4626 deposit/mint/withdraw/redeem with receiver/owner = this.
- **Other whitelisted targets** (Rule 4): Require selector to be explicitly in the allowed list for that target. No selectors set = no calls allowed.

### State

```solidity
mapping(address => mapping(bytes4 => bool)) public s_allowedSelectors;
```

### Owner Functions

```solidity
/// @notice Add an allowed selector for a whitelisted target
function addAllowedSelector(address target, bytes4 selector) external onlyOwner;

/// @notice Remove an allowed selector
function removeAllowedSelector(address target, bytes4 selector) external onlyOwner;

/// @notice Set all allowed selectors for a target (replaces existing). Empty array = no selectors allowed.
function setAllowedSelectors(address target, bytes4[] calldata selectors) external onlyOwner;
```

### Modify `_validateAction` (Rule 4)

```solidity
// ── Rule 4: Other whitelisted targets — only explicitly allowed selectors ──
if (!s_isWhitelistedTarget[target]) return false;
if (data.length < 4) return false;
bytes4 selector = bytes4(data[:4]);
return s_allowedSelectors[target][selector];
```

### Example Selectors per Protocol

| Protocol | Selectors |
|----------|-----------|
| Lending (Compound) | `supply(uint256)`, `redeem(uint256)`, `redeemUnderlying(uint256)` |
| Lending (Aave) | `supply(address,uint256,address,uint16)`, `withdraw(address,uint256,address)` |
| NadFunBuyAdapter | `buyCeo(address,address,uint256)` |
| CEOVaultSwapAdapter | `executeActions(bytes)` |

### Errors & Events

```solidity
error SelectorNotAllowed();
event AllowedSelectorSet(address indexed target, bytes4 indexed selector, bool allowed);
```
