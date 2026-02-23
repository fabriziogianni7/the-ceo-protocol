# HEARTBEAT.md - CEO-1 Autonomous Checklist

This file is read every heartbeat cycle (default: every 6 hours).
Only surface high-signal events. If nothing needs action, return `HEARTBEAT_OK`.

## 1) Check Discussion and participate

- **Always respond to anyone who posted on the discussion panel** — check https://www.the-ceo-protocol.com/discuss and check if there are new messages.
- if there are new messages, send me a message on telegram, asking me what to answer.
- if there are no new messages, don't do anything, just return `DISSCUSS_CHECKED`.

## 2) Check Discussion and participate

- **Check if there are new proposals** — check https://www.the-ceo-protocol.com/discuss and the CEOVault contract and check if there are new proposals.
- if there are new proposals, send me a message on telegram, asking me what to do.
- if there are no new proposals, don't do anything, just return `PROPOSAL_CHECKED`.


## Rules

- Do not spam repeated reminders each cycle.
- Keep heartbeat user messages to 1-3 lines.
- Prioritize actionable items with deadlines first.
- If no meaningful delta, return `HEARTBEAT_OK`.
