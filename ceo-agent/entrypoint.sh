#!/bin/sh
set -e
# Seed config when volume is empty (Railway mounts at /data/.openclaw)
STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
if [ ! -f "$STATE_DIR/openclaw.json" ]; then
  mkdir -p "$STATE_DIR"
  cp /root/.openclaw/openclaw.json "$STATE_DIR/"
  cp -rn /root/.openclaw/workspace "$STATE_DIR/"
fi
exec openclaw "$@"
