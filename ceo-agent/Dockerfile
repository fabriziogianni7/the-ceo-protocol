# ---- Build stage (reserved) ----
FROM node:22-slim AS builder

RUN npm install -g pnpm


# ---- Runtime stage: lean final image ----
FROM node:22-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@latest

# Install local viem signer plugin CLI
COPY ceo-agent/plugins/viem-local-signer/ /opt/viem-local-signer/
RUN cd /opt/viem-local-signer && npm install && npm run build && npm install -g .

# Install viem signer skill TypeScript scripts
COPY ceo-agent/skills/viem-signer-skill/scripts/ /opt/viem-signer-skill-scripts/
RUN cd /opt/viem-signer-skill-scripts && npm install && npm run build

# Install ERC-8004 helper scripts dependencies
COPY ceo-agent/skills/8004-skill/scripts/ /opt/erc8004-scripts/
RUN cd /opt/erc8004-scripts && npm install

# Pond3r MCP CLI scripts (plain Node, no deps; uses POND3R_API_KEY from env)
COPY ceo-agent/skills/pond3r-skill/scripts/ /opt/pond3r-skill-scripts/

# OpenClaw runtime paths
ENV OPENCLAW_STATE_DIR=/root/.openclaw
ENV MOLTBOT_STATE_DIR=/root/.moltbot

COPY ceo-agent/openclaw.json /root/.openclaw/openclaw.json
COPY ceo-agent/workspace/ /root/.openclaw/workspace/
COPY ceo-agent/skills/ /root/.openclaw/workspace/skills/

EXPOSE 18789

# Cap Node heap to avoid OOM on Railway (512MB containers). Override via Railway env if you have more RAM.
ENV NODE_OPTIONS="--max-old-space-size=256"

# Set TELEGRAM_BOT_TOKEN and required model/RPC env vars via .env
CMD ["openclaw", "gateway", "--bind", "loopback"]
