#!/bin/sh
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/root/.openclaw}"
DEFAULTS="/opt/openclaw-defaults"

echo "[entrypoint] OPENCLAW_STATE_DIR=$STATE_DIR"

mkdir -p "$STATE_DIR"
cp -f "$DEFAULTS/openclaw.json" "$STATE_DIR/openclaw.json"
cp -rf "$DEFAULTS/workspace" "$STATE_DIR/"

echo "[entrypoint] config synced to $STATE_DIR"
echo "[entrypoint] TELEGRAM_BOT_TOKEN is $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo 'set' || echo 'NOT SET')"

exec openclaw "$@"
