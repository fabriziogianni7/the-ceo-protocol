---
name: viem-signer-skill
description: Use a minimal local signer plugin for raw tx signing, plus deterministic TypeScript viem scripts for reads and writes.
---

# viem Signer Skill (Signer + TS scripts)

Use this skill for all onchain operations. Architecture:

- **Plugin (`viem-local-signer`)**: minimal raw signer using private key from env.
- **Skill scripts (TypeScript + viem)**: deterministic read/write/send flows.

This enforces separation of concerns: scripts prepare txs, signer only signs/sends raw payloads.

## Security posture

- Use burner wallet only for this local signer mode.
- Never print private keys or raw secrets.
- Never install random blockchain libraries at runtime for onchain tasks.
- Prefer SIWA/keyring proxy in production.

## Required env vars

- `MONAD_RPC_URL`
- `MONAD_CHAIN_ID` (default `143`)
- `AGENT_PRIVATE_KEY`
- `AGENT_ADDRESS` (recommended)

## Block explorer

- `https://monadscan.com/`
- Tx: `https://monadscan.com/tx/<hash>`

## Signer plugin (minimal)

Available commands:

```bash
viem-local-signer address
viem-local-signer sign-raw --tx-json '{"to":"0x...","data":"0x","value":"0","gas":"21000","nonce":1,"chainId":143,"type":"legacy","gasPrice":"1000000000"}'
viem-local-signer sign-raw --tx-file /tmp/tx.json
viem-local-signer send-signed --signed-tx 0x... --wait
```

Notes:
- `sign-raw` expects a **fully prepared transaction**.
- For legacy txs include `gasPrice`.
- For EIP-1559 txs include `type: "eip1559"`, `maxFeePerGas`, `maxPriorityFeePerGas`.

## TypeScript scripts (preferred)

Scripts are in:

- `/root/.openclaw/workspace/skills/viem-signer-skill/scripts`
- installed runtime deps in `/opt/viem-signer-skill-scripts`

Run compiled scripts with:

```bash
node /opt/viem-signer-skill-scripts/dist/<script>.js [args...]
```

### 1) Read contract data

```bash
node /opt/viem-signer-skill-scripts/dist/read-contract.js \
  --to 0xdb60410d2dEef6110e913dc58BBC08F74dc611c4 \
  --abi-file /root/.openclaw/workspace/snippets/ceovault-read-abi.json \
  --function s_minCeoStake \
  --args-json "[]"
```

### 2) Send native MON (signed by plugin)

```bash
node /opt/viem-signer-skill-scripts/dist/send-native.js \
  --to 0xRecipientAddress \
  --value-eth 0.01 \
  --wait
```

### 3) Write contract call (approve/transfer/mint/etc)

```bash
node /opt/viem-signer-skill-scripts/dist/write-contract.js \
  --to 0xContractAddress \
  --abi-file /root/.openclaw/workspace/snippets/erc20-abi.json \
  --function approve \
  --args-json "[\"0xdb60410d2dEef6110e913dc58BBC08F74dc611c4\",\"1000000000000000000\"]" \
  --value-wei 0 \
  --wait
```

Gas behavior:
- If `--gas` is omitted, gas is auto-estimated and a +20% buffer is applied by default.
- Override buffer with `--gas-buffer-percent <n>` (e.g. `30`).
- Set exact gas manually with `--gas <wei>`.

### 4) Broadcast a pre-signed transaction

```bash
node /opt/viem-signer-skill-scripts/dist/broadcast-signed.js \
  --signed-tx 0xSerializedTransaction \
  --wait
```

## Onchain policy (mandatory)

- For **all** onchain reads/writes, use this skill scripts + signer plugin.
- Do not switch to ad-hoc ethers/viem installs during a task.
- Present summary and ask user confirmation before state-changing txs.
- Return concrete tx hash/receipt from executed commands.

## Failure handling

- `Missing required env var`: set env values in `.env`.
- RPC `Invalid params`: ensure tx fields match legacy vs EIP-1559 mode.
- Address mismatch: fix `AGENT_ADDRESS` / `AGENT_PRIVATE_KEY`.
- Never leak private keys in logs or chat.
