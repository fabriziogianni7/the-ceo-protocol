# Uniswap V4 + nad.fun Integration for CEOVault `convertPerformanceFee`

This document describes the USDC→MON→$CEO flow and requirements for `CEOVaultForkUniswap` and production.

## Run the Integration Test

```bash
export MONAD_RPC_URL=https://monad-mainnet.g.alchemy.com/v2/YOUR_KEY
forge test --match-contract CEOVaultForkUniswap --fork-url $MONAD_RPC_URL
```

## What You Need

### 1. **PoolKey for USDC → $CEO (or USDC → MON → $CEO)**

A `PoolKey` identifies a Uniswap V4 pool:

```solidity
struct PoolKey {
    Currency currency0;   // Lower address (address(currency0) < address(currency1))
    Currency currency1;   // Higher address
    uint24 fee;           // e.g. 3000 (0.3%), 500 (0.05%), 10000 (1%)
    int24 tickSpacing;    // e.g. 60 for 0.3%, 10 for 0.05%
    IHooks hooks;         // address(0) for vanilla pool
}
```

- **USDC on Monad:** `0x754704Bc059F8C67012fEd69BC8A327a5aafb603`
- **$CEO on Monad:** `0xCA26f09831A15dCB9f9D47CE1cC2e3B086467777`
- **Address order:** USDC < $CEO, so `currency0 = USDC`, `currency1 = $CEO`

**If there is no direct USDC/$CEO pool:**
- Use a two-hop path: USDC → MON (Uniswap V4) → $CEO (nad.fun or another DEX)
- The current test only supports a single-hop swap
- You would need to extend `SwapPlanner` or add a second swap action

### 2. **Pool Parameters (fee, tickSpacing, hooks)**

Common Uniswap V4 fee tiers:

| Fee (bps) | tickSpacing | Typical use |
|-----------|-------------|-------------|
| 500       | 10          | 0.05%       |
| 3000      | 60          | 0.3%        |
| 10000     | 200         | 1%          |

The pool id `0x18a9fc874581f3ba12b7898f80a683c66fd5877fd74b26a85ba9a3a79c549954` (from notes) may correspond to a MON/USDC pool. To discover the correct PoolKey:

1. **Use the Uniswap V4 Quoter** on Monad (`0xa222Dd357A9076d1091Ed6Aa2e16C9742dD26891`) to try `quoteExactInputSingle` with different PoolKeys until one succeeds.
2. **Check subgraph or deployment docs** for the Monad Uniswap V4 pool configuration.
3. **Brute-force:** Try common combinations (3000/60, 500/10, 10000/200) with `hooks = address(0)`.

### 3. **CEOVaultSwapAdapter**

Deploy `CEOVaultSwapAdapter` (see `test/adapters/CEOVaultSwapAdapter.sol`):

- Constructor: `IPoolManager` address (Monad: `0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e`)
- Whitelist it in CEOVault: `vault.setWhitelistedTarget(adapter, true)`

### 4. **convertPerformanceFee Actions**

Two actions are required:

1. **Approve:** `IERC20(USDC).approve(swapAdapter, amount)` so the adapter can pull USDC.
2. **Execute swap:** `swapAdapter.executeActions(swapData)` where `swapData` is built by `SwapPlanner.encodeExactInputSingle(...)`.

### 5. **Swap Direction (zeroForOne)**

- `zeroForOne = true` → swap currency0 → currency1 (USDC → $CEO)
- `zeroForOne = false` → swap currency1 → currency0

### 6. **Slippage (minCeoOut)**

Set `minCeoOut` in `convertPerformanceFee(actions, minCeoOut)` to protect against slippage. Use the Quoter to get an expected output, then apply a tolerance (e.g. 0.5%–1%).

## Architecture

```
CEOVault.convertPerformanceFee(actions, minCeoOut)
  ├─ Action 1: USDC.approve(swapAdapter, amount)
  └─ Action 2: swapAdapter.executeActions(swapData)
                  └─ PoolManager.unlock(swapData)
                       └─ unlockCallback → SWAP_EXACT_IN_SINGLE, SETTLE_ALL, TAKE_ALL
                            └─ _pay: transferFrom(vault, poolManager, amount)
                            └─ _take: poolManager.take(currencyOut, vault, amountOut)
```

The vault must hold sufficient idle USDC (or have pulled from yield vaults) before calling `convertPerformanceFee`.

## USDC → MON → $CEO Flow (nad.fun)

The `CEOVaultForkUniswap` test implements the full flow:

1. **Vault transfers USDC** to CEOVaultSwapAdapter (V4 locker must hold input tokens)
2. **Uniswap V4 swap** USDC → MON, output to NadFunBuyAdapter
3. **NadFunBuyAdapter.buyCeo()** spends received MON to buy $CEO on nad.fun, sends to vault

### nad.fun Addresses (Monad mainnet)

- BONDING_CURVE_ROUTER: `0x6F6B8F1a20703309951a5127c45B49b1CD981A22`
- DEX_ROUTER: `0x0B79d71AE99528D1dB24A4148b5f4F865cc2b137`
- LENS: `0x7e78A8DE94f21804F7a17F4E8BF9EC2c872187ea`

Use `Lens.getAmountOut(CEO, monAmount, true)` to choose router and get `amountOutMin` for production.

## References

- [Uniswap V4 Docs](https://docs.uniswap.org) — Hooks, PoolManager, swap flow
- [v4-periphery](https://github.com/Uniswap/v4-periphery) — V4Router, Planner, Actions
- CEOVault `convertPerformanceFee`: `src/CEOVault.sol` lines 382–416
