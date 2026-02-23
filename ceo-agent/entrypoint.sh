#!/bin/sh
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/root/.openclaw}"
DEFAULTS="/opt/openclaw-defaults"

echo "[entrypoint] OPENCLAW_STATE_DIR=$STATE_DIR"
echo "[entrypoint] TELEGRAM_BOT_TOKEN is $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo 'set' || echo 'NOT SET')"

# Clear any stale webhook so long polling works (only one consumer per token)
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  echo "[entrypoint] Clearing any existing Telegram webhook..."
  curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook" >/dev/null || true
fi

mkdir -p "$STATE_DIR"

# Expand env var placeholders (Telegram uses TELEGRAM_BOT_TOKEN env directly, no config needed)
sed -e "s#\${BRAVE_API_KEY}#${BRAVE_API_KEY}#g" \
  "$DEFAULTS/openclaw.json" > "$STATE_DIR/openclaw.json"

cp -rf "$DEFAULTS/workspace" "$STATE_DIR/"

echo "[entrypoint] config synced to $STATE_DIR"

exec openclaw "$@"


