---
title: Models and providers
---

# Models and providers

## Switching

`Ctrl+P` cycles forward through the scoped models, `Shift+Ctrl+P` backward. `Ctrl+L` opens the full model selector; `/scoped-models` edits which models the cycle includes.

The cycle is defined by `enabledModels` in `settings.json`:

```json
"enabledModels": [
  "openai-codex/gpt-5.6-sol",
  "openai-codex/gpt-5.6-terra",
  "openai-codex/gpt-5.5",
  "xai-oauth/grok-4.6",
  "xai-oauth/grok-build"
]
```

The default on startup is `openai-codex/gpt-5.5` at `high` thinking. `Shift+Tab` cycles the thinking level independently of the model. OpenCode and OpenRouter models stay available from the full picker (`Ctrl+L`, scope **all**).

## Context is shared across providers

Switching model mid-session does **not** start a new conversation. The session holds one message history; Pi re-serializes it for whichever provider is selected next. Three things do change when you cross a provider boundary:

- **Prompt caching resets.** Caches are per-provider, so the first turn after a switch pays full input price. The [statusline](./statusline.md) will show the cost jump.
- **Reasoning blocks do not transfer.** Provider-specific thinking content is not replayable to a different provider; the text of the conversation survives, the internal reasoning does not.
- **The context window changes.** `grok-4.6` has a 500K window; the `gpt-5.6` models are smaller. Switching down from a large window into a smaller one can push the session straight into compaction.

Switch deliberately at a turn boundary, not mid-task, and the history follows you.

## Credentials

Credentials live in `~/.pi/agent/auth.json` and are never tracked in this repository. Establish them per machine:

```bash
pi auth check --provider openai-codex   # ready | not configured
```

| Provider | How it authenticates | Notes |
| --- | --- | --- |
| `openai-codex` | OAuth via `/login` | The default provider. Uses the ChatGPT subscription, independent of the `~/.codex` CLI's own token. |
| `xai-oauth` | SuperGrok OAuth via `/login` | From `git:github.com/stnly/pi-grok`. The cycle includes `grok-4.6` and `grok-build`. Rides the SuperGrok quota through the CLI chat proxy, not billed `api.x.ai` credits. |

Pi keeps its own credential store. It does not read `~/.codex/auth.json` or `~/.local/share/opencode/auth.json`, and copying tokens between them is not necessary — each tool logs in on its own.

## Refreshing the catalogue

```bash
pi update --models
```

Model catalogues are cached in `~/.pi/agent/models-store.json` and refresh automatically; run the command to force it after a provider ships something new.
