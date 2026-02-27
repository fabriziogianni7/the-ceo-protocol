# Draft: ERC-8004 Registration — Automatic Registry Handling

This document describes proposed changes to **CEOVaultV2** so that agent registration automatically handles ERC-8004 identity registration when needed. The original CEOVault is not modified.

## Design Principle

**Registering an agent should call the registry and handle the registration automatically.** Users should not need to perform a separate transaction to register with the ERC-8004 Identity Registry before calling `registerAgent`. The vault should orchestrate both steps in a single call when the user does not yet have an identity.

---

## Part A: Problem Statement

**Current flow:**
1. User must first call `IERC8004Identity.register(agentURI)` on the ERC-8004 Identity Registry to mint an identity NFT.
2. User receives an `agentId` (ERC-721 token ID).
3. User then calls `CEOVaultV2.registerAgent(metadataURI, ceoAmount, erc8004Id)` with that ID.

**Result:** Two separate transactions. Users must:
- Know about the ERC-8004 registry and its address.
- Call it first, wait for confirmation, then call the vault.
- Handle the case where they already have an identity vs. do not.

This creates friction, increases gas (two txs), and is error-prone (wrong ID, wrong order, etc.).

---

## Part B: Solution — Automatic ERC-8004 Registration

**Approach:** When `registerAgent` is called with `erc8004Id == 0`, the vault automatically calls the ERC-8004 Identity Registry to register the caller and obtain an identity. When `erc8004Id > 0`, the vault uses the provided ID (existing behavior). This preserves backward compatibility and supports both flows.

### 1. Modified `registerAgent` signature and logic

**Current:**
```solidity
function registerAgent(string calldata metadataURI, uint256 ceoAmount, uint256 erc8004Id) external nonReentrant
```
- Requires `erc8004Id != 0` and caller must own it.

**Proposed:** Same signature. New behavior when `erc8004Id == 0`:
- Call `s_erc8004Identity.register(metadataURI)`. The registry mints the identity NFT to the vault (msg.sender of the call).
- Transfer the NFT to the agent via `IERC721(identity).transferFrom(address(this), msg.sender, agentId)`.
- Use the returned `agentId` as the linked identity.

```solidity
/// @notice Register as an agent by staking $CEO and linking an ERC-8004 identity
/// @param metadataURI Agent's metadata URI (capabilities, endpoints). Also used for ERC-8004 registration when erc8004Id is 0.
/// @param ceoAmount Amount of $CEO to stake (must be >= minCeoStake)
/// @param erc8004Id ERC-8004 identity NFT ID. Use 0 to auto-register with the Identity Registry; otherwise must be owned by caller.
function registerAgent(string calldata metadataURI, uint256 ceoAmount, uint256 erc8004Id) external nonReentrant {
    if (s_agents[msg.sender].active) revert AlreadyRegistered();
    if (ceoAmount < s_minCeoStake) revert InsufficientCeoStake();
    if (s_agentList.length >= s_maxAgents) revert MaxAgentsReached();

    if (address(s_erc8004Identity) == address(0)) revert IdentityRegistryNotConfigured();

    uint256 linkedId;
    if (erc8004Id == 0) {
        linkedId = s_erc8004Identity.register(metadataURI);
        IERC721(address(s_erc8004Identity)).transferFrom(address(this), msg.sender, linkedId);
    } else {
        if (s_erc8004Identity.ownerOf(erc8004Id) != msg.sender) revert NotOwnerOfERC8004Identity();
        linkedId = erc8004Id;
    }

    // Transfer $CEO stake
    i_ceoToken.safeTransferFrom(msg.sender, address(this), ceoAmount);

    // Register
    s_agents[msg.sender] = Agent({
        active: true,
        ceoStaked: ceoAmount,
        score: 0,
        erc8004Id: linkedId,
        metadataURI: metadataURI,
        registeredAt: block.timestamp
    });

    s_agentList.push(msg.sender);

    emit AgentRegistered(msg.sender, ceoAmount, metadataURI);
    emit ERC8004IdentityLinked(msg.sender, linkedId);
}
```

### 2. Remove `NoERC8004IdentityLinked` for `erc8004Id == 0`

**Current:** `if (erc8004Id == 0) revert NoERC8004IdentityLinked();`

**Proposed:** When `erc8004Id == 0`, we no longer revert; we instead trigger auto-registration. The error `NoERC8004IdentityLinked` is no longer applicable in this flow (it could be repurposed or removed from the interface if it becomes unused).

### 3. Behavior summary

| `erc8004Id` | Behavior |
|-------------|----------|
| `0` | Vault calls `s_erc8004Identity.register(metadataURI)`. Caller receives a new identity NFT. Vault uses returned ID. Single tx for new agents. |
| `> 0` | Caller must own the identity. Vault links that ID. Same as current behavior. For agents who already registered elsewhere. |

---

## Part C: Edge Cases and Considerations

### 3.1 Caller already has an identity

If the caller already has an ERC-8004 identity, they should pass it as `erc8004Id` to avoid minting a duplicate. The vault does not check "does this address already have an identity?" — that is the caller's responsibility. Passing `0` always creates a new identity.

### 3.2 `metadataURI` usage

When `erc8004Id == 0`, `metadataURI` is passed to `s_erc8004Identity.register(metadataURI)`. The registry typically uses this as the agent URI / token URI. The vault also stores it in `Agent.metadataURI`. Both uses are consistent.

### 3.3 Registry reverts

If `s_erc8004Identity.register(metadataURI)` reverts (e.g. registry paused, rate limit), the entire `registerAgent` call reverts. No partial state. This is acceptable: the user retries when the registry is available.

### 3.4 Gas

- **erc8004Id == 0:** One extra external call (to the registry). Slightly higher gas than the current "pre-registered" path, but eliminates a separate user transaction.
- **erc8004Id > 0:** Same as today (one `ownerOf` call).

---

## Part D: Deregistration

`deregisterAgent` does not need to change. The ERC-8004 identity NFT remains with the user; the vault only unlinks the agent. If the user re-registers later, they can pass their existing `erc8004Id` to avoid minting another identity.

---

## Part E: New Errors / Events

No new errors or events are required. Existing ones suffice:
- `IdentityRegistryNotConfigured` — when registry is not set
- `NotOwnerOfERC8004Identity` — when `erc8004Id > 0` but caller does not own it
- `ERC8004IdentityLinked` — emitted with the linked ID (whether auto-registered or pre-existing)

**Optional:** Add an event to distinguish auto-registration for analytics:
```solidity
event ERC8004IdentityAutoRegistered(address indexed agent, uint256 agentId);
```
Emit when `erc8004Id == 0` and registration succeeds. Leave as future enhancement if not needed.

---

## Part F: Files to Modify

| File | Action |
|------|--------|
| `ICEOVaultV2.sol` | Update NatSpec for `registerAgent` to document `erc8004Id == 0` behavior. Clarify `NoERC8004IdentityLinked`. |
| `test/mocks/MockERC8004Identity.sol` | Add `transferFrom` for tests (real ERC-8004 registry is ERC721 and has it). |
| `CEOVaultV2.sol` | Add IERC721 import; modify `registerAgent`: when `erc8004Id == 0`, call `s_erc8004Identity.register(metadataURI)`, transfer NFT to agent via `IERC721.transferFrom`, use returned ID; otherwise validate ownership and use provided ID. |

---

## Part G: Migration / Compatibility

- **Backward compatible:** Agents who already have an identity continue to pass `erc8004Id > 0`. Behavior unchanged.
- **New UX:** Agents without an identity pass `erc8004Id = 0` and get automatic registration in one tx.
- **Tests:** Update tests that currently require pre-registration; add tests for `erc8004Id == 0` path.

---

## Part H: Test Cases to Add/Update

1. **`test_registerAgent_autoRegisterWhenErc8004IdZero`** — Call `registerAgent(metadataURI, ceoAmount, 0)`. Assert identity was minted to caller, agent is registered with that ID.
2. **`test_registerAgent_existingIdentityWhenErc8004IdNonZero`** — Pre-register, then `registerAgent(..., id)`. Assert same behavior as before.
3. **`test_registerAgent_revert_autoRegisterWhenRegistryNotConfigured`** — With `s_erc8004Identity == address(0)`, `registerAgent(..., 0)` reverts with `IdentityRegistryNotConfigured`.
4. **`test_registerAgent_revert_notOwnerWhenErc8004IdNonZero`** — Pass `erc8004Id` owned by another address; assert `NotOwnerOfERC8004Identity`.

---

## Part I: Open Questions / Future Enhancements

1. **Metadata entries:** `IERC8004Identity.register(string, MetadataEntry[])` supports richer metadata. Should we add an overload `registerAgent(metadataURI, ceoAmount, metadataEntries)` that passes metadata to the registry? Leave as future enhancement.
2. **`register()` with no URI:** Some registries support `register()` with no URI. We use `metadataURI` for both vault and registry; no change needed unless we want a "minimal" registration path.
3. **Analytics:** Emit `ERC8004IdentityAutoRegistered` to distinguish first-time vs. existing-identity registrations for dashboards.
