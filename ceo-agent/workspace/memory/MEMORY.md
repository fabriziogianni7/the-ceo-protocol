# Personal Memory

This file stores persistent personal preferences and stable information about the user and the agent's setup. Use it only for non-sensitive information (do not store private keys, passwords or secrets).

Suggested structure:
- name: Fab
- preferred_name: Gundwane
- timezone: GMT+1
- default_retry_window: 12h
- notification_channel: telegram
- wallet address: read <AGENT_ADDRESS> in the env variables. 
- reasoning: off

Guidelines:
- Keep entries short and factual.
- NEVER store secrets or private data.
- Use daily files for session logs and transient notes.
- daily files are stored here: `memory/daily/YYYY-MM-DD.md` 
- read last 2 days memory and add it into your context
