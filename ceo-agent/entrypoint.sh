#!/bin/sh
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/root/.openclaw}"
echo "[entrypoint] OPENCLAW_STATE_DIR=$STATE_DIR"

# Always sync config + workspace from the image into the state dir
mkdir -p "$STATE_DIR"
cp -f /root/.openclaw/openclaw.json "$STATE_DIR/openclaw.json"
cp -rf /root/.openclaw/workspace "$STATE_DIR/"

echo "[entrypoint] config synced to $STATE_DIR"
echo "[entrypoint] TELEGRAM_BOT_TOKEN is $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo 'set' || echo 'NOT SET')"

exec openclaw "$@"
