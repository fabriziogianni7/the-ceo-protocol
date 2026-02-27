# Draft: #3 Deposit Hook — Deploy Idle Capital Immediately

This document describes proposed changes to **CEOVaultV2** to deploy capital immediately on deposit, avoiding idle USDC sitting in the vault for days. The original CEOVault is not modified.

## Design Principle

**Capital should never be idle.** When a user deposits USDC, the vault should deploy it to yield vaults according to a configurable default allocation, rather than waiting for the next epoch and governance execution.

---

## Part A: Problem Statement

**Current flow:**
1. User calls `deposit(assets, receiver)` → USDC stays idle in the vault.
2. Capital is deployed only when `execute(proposalId, actions)` runs, where one action is `executeRebalance(allocations)`.
3. Execution requires: epoch to end, voting to finish, winning proposal, and someone to call `execute`.

**Result:** Deposits can sit idle for days (until the next epoch ends and someone executes).

---

## Part B: Solution — Deposit Hook 

**Approach:** On each deposit, split the **net deposit** (assets minus fee) by the default allocation percentages and deposit each slice directly into the corresponding yield vaults. No full rebalance — no withdrawals, only deposits of new capital.

### 1. Default allocation storage

Add state variables to store the owner-configured default allocation:

```solidity
// ── Default Allocation (deposit hook) ──
address[MAX_ALLOCATION_TARGETS] public s_defaultVaults;
uint256[MAX_ALLOCATION_TARGETS] public s_defaultBps;
uint8 public s_defaultCount;  // 0 = hook disabled
```

**Storage format:** Parallel arrays. `s_defaultCount` is the number of entries; `s_defaultVaults[i]` and `s_defaultBps[i]` for `i < s_defaultCount` form the allocation.

### 2. New function: `deployDeposit`

Splits an amount by default allocation percentages and deposits each slice into the corresponding vault. Self-call only (called from `_deposit`).

```solidity
/// @notice Deploy an amount to yield vaults per default allocation (self-call only).
/// @dev Called from _deposit hook. Splits amount by s_defaultBps and deposits each slice.
///      Simpler than full rebalance: no withdrawals, only deposits of new capital.
/// @param amount Net deposit amount to deploy (assets minus fee)
function deployDeposit(uint256 amount) external {
    if (msg.sender != address(this)) revert DeployDepositOnlySelf();
    if (s_defaultCount == 0) return;
    if (amount == 0) return;

    for (uint8 i = 0; i < s_defaultCount; i++) {
        uint256 slice = amount * s_defaultBps[i] / 10_000;
        if (slice > 0) {
            address vault = s_defaultVaults[i];
            IERC20(asset()).forceApprove(vault, slice);
            try IERC4626(vault).deposit(slice, address(this)) {
                // Success
            } catch {
                IERC20(asset()).forceApprove(vault, 0);
                revert ActionFailed();
            }
            IERC20(asset()).forceApprove(vault, 0);
        }
    }
}
```

### 3. Deposit hook in `_deposit`

After `super._deposit()` and fee distribution, deploy the net deposit when default allocation is configured:

```solidity
// Deploy net deposit to yield vaults per default allocation (if configured)
if (s_defaultCount > 0) {
    uint256 netDeposit = assets - fee;
    if (netDeposit > 0) {
        try this.deployDeposit(netDeposit) {} catch {
            // Leave capital idle on failure; do not revert deposit
        }
    }
}
```

**Why `this.deployDeposit` instead of an internal call?** Solidity's `try/catch` only works with external function calls — it cannot wrap internal calls. If we called an internal deploy function directly and it reverted (e.g. yield vault paused), the entire deposit would revert and the user would not receive shares. By using `this.deployDeposit(netDeposit)` (external self-call), we can catch failures: on revert, we swallow the error and the deposit succeeds; capital simply stays idle.

### 4. Reentrancy protection

The deposit flow now performs external calls (to yield vaults) after the base deposit. Add `nonReentrant` to the deposit entry points. Override `deposit` and `mint`:

```solidity
function deposit(uint256 assets, address receiver) public virtual override nonReentrant returns (uint256) {
    return super.deposit(assets, receiver);
}

function mint(uint256 shares, address receiver) public virtual override nonReentrant returns (uint256) {
    return super.mint(shares, receiver);
}
```

### 5. Owner configuration: set default allocation

```solidity
function setDefaultAllocation(address[] calldata vaults, uint256[] calldata bps) external onlyOwner {
    if (vaults.length != bps.length) revert InvalidAllocationCount();
    if (vaults.length > MAX_ALLOCATION_TARGETS) revert InvalidAllocationCount();

    uint256 totalBps;
    for (uint256 i = 0; i < vaults.length; i++) {
        if (!s_isYieldVault[vaults[i]]) revert InvalidAllocationVault();
        totalBps += bps[i];
        s_defaultVaults[i] = vaults[i];
        s_defaultBps[i] = bps[i];
    }
    if (totalBps > 10_000) revert AllocationBpsExceedMax();

    s_defaultCount = uint8(vaults.length);
    emit DefaultAllocationSet(vaults.length);
}

function clearDefaultAllocation() external onlyOwner {
    s_defaultCount = 0;
    emit DefaultAllocationCleared();
}
```

### 6. New errors and events

```solidity
error DeployDepositOnlySelf();

event DefaultAllocationSet(uint256 count);
event DefaultAllocationCleared();
```

---

## Part C: Deposit-Only vs Full Rebalance

| Aspect | Deposit-only (implemented) | Full rebalance |
|--------|----------------------------|----------------|
| **Logic** | Split net deposit by %, deposit each slice | Compute targets from totalAssets, withdraw + deposit |
| **Gas** | Lower (deposits only) | Higher (withdraws + deposits) |
| **Existing idle** | Not deployed | Deployed |
| **Allocation drift** | Not corrected | Corrected |
| **Use case** | Deploy new deposits immediately | Full portfolio rebalance (governance) |

**Note:** `executeRebalance` remains for governance. The deposit hook uses the simpler `deployDeposit`. Governance can still rebalance periodically to correct drift.

---

## Part D: Behavior Summary

| Scenario | Behavior |
|----------|----------|
| `s_defaultCount == 0` | No hook; deposit behaves as today; capital stays idle until governance executes. |
| `s_defaultCount > 0` | After each deposit, net deposit is split by default allocation and deployed to yield vaults. |
| Deploy fails (e.g. yield vault paused) | try/catch swallows; deposit succeeds; capital stays idle. |
| Existing idle before deposit | Stays idle until governance rebalances. |

---

## Part E: Gas Considerations

- Deposit-only is cheaper than full rebalance (no withdraw phase).
- **Optional:** Add a minimum amount threshold: only deploy if `netDeposit >= s_minDeployAmount`. *Leave as future enhancement if not needed.*

---

## Part F: Files to Modify

| File | Action |
|------|--------|
| `ICEOVaultV2.sol` | Add `DeployDepositOnlySelf` error; add `DefaultAllocationSet`, `DefaultAllocationCleared` events |
| `CEOVaultV2.sol` | Add `s_defaultVaults`, `s_defaultBps`, `s_defaultCount`; add `deployDeposit`; add deposit hook in `_deposit`; override `deposit`/`mint` with `nonReentrant`; add `setDefaultAllocation`, `clearDefaultAllocation` |

---

## Part G: Migration / Compatibility

- **Default:** `s_defaultCount == 0` at deployment. Deposit hook is disabled; behavior identical to current.
- **Backward compatible:** Owner can enable the hook by calling `setDefaultAllocation`, or leave it disabled.

---

## Part H: Open Questions / Future Enhancements

1. **Minimum deploy amount:** Add `s_minDeployAmount` to skip deploy for tiny deposits and reduce gas?
2. **Permissionless `deployIdle()`:** Add a function callable by anyone (relayer, automation) that deploys all idle capital. Could complement the hook.
3. **Epoch / governance interaction:** The default allocation is independent of governance. Agents can still propose different allocations; execution via `execute()` would rebalance to the new target. The hook does not conflict with governance.
