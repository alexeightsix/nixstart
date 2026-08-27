---
title: Roadmap
sidebar_position: 98
---

# Roadmap

Wanted, not built. Each entry records what it should do and what standing in the way, so picking one up does not start from scratch.

## Broader built-in toolset

**Want:** audit the capability set in oh-my-pi's “Whatever the task needs, it's already in the box” inventory and add the useful gaps to this Pi configuration without blindly cloning its interface or loading a large permanent prompt surface.

The current configuration already covers ordinary file I/O and search (`read`, `write`, `edit`, `grep`, `find`, `ls`, `bash`), plans (`todo`), structured questions, [read-only subagents](./subagents.md), browser automation through MCP, GitHub through `gh`, image inspection through the active model, session statistics and local notes. Read-only [LSP tools](./lsp.md) provide semantic Go and TypeScript navigation.

Candidate additions, grouped by the job they enable:

| Area | Candidates | Design constraint |
| --- | --- | --- |
| Structural code work | `ast_grep`, preview-first `ast_edit` | Use established ast-grep tooling; mutations must pass permission modes and show an exact preview. |
| Runtime exploration | persistent JavaScript/Python `eval`, background job supervision | Isolate state per session, cap output and time, and guarantee shutdown cleanup. |
| Code intelligence | LSP rename, type definition, implementation, code actions and raw requests; DAP debugging | Read-only LSP ships first. Any action that edits or executes must be gated as a write/runtime action. |
| Coordination | richer chains, live-agent messaging and cross-host cancellation | Extend the bounded read-only subagent tool rather than create an unrelated process pool or parallel writers. |
| Web and desktop | direct browser, host-computer control, web search, GitHub, image generation and speech | Prefer existing MCP or trusted CLI integrations; desktop control and generated media require explicit approval and narrow scopes. |
| Durable memory | checkpoints, rewind, retain/recall/reflect, managed lessons and skills | Keep transcript state distinct from durable memory, make deletion explicit, and avoid silently promoting conversation content. |
| Security | repository-native security scans | Start with local, inspectable scanners; cloud scans require an explicit provider and data-sharing contract. |

### Delivery order

1. Finish and verify read-only LSP navigation for Go and native TypeScript.
2. Add structural search before structural mutation.
3. Prototype persistent eval and job lifecycle with strict cancellation and output limits.
4. Design mutating LSP, DAP and desktop actions together with permission-mode enforcement.
5. Add durable memory only after retention, redaction and deletion semantics are documented.

### Standing constraints

- A single proxy/action tool is preferred when many related operations would otherwise bloat every model prompt.
- “Already available through Bash or MCP” is not automatically a reason to add another wrapper; a wrapper must improve safety, structure, context cost or verification.
- Every mutating capability must participate in `ask` and `read-only` modes. Read-only wrappers must not expose a generic escape hatch that bypasses those modes.
- External projects are design references, not the source of truth for this configuration. Each adopted capability needs its own local requirement, documentation and evidence.

## Notification sink for other apps

**Want:** notifications written to a file or fifo as well as sent to dunst, so a bar, a phone bridge, or another machine can consume them.

Cheap to add: `notify.ts` already funnels every toast through one function, so a JSONL append next to the `notify-send` call covers it. The open questions are where it lives (per-session under the agent dir, or one global stream) and whether anything should rotate it — see [/gc](./housekeeping.md), which already prunes the other append-only logs.

## `/remote` — pipe into a running session from another terminal

**Want:** `/remote` puts a session into a receive-only state — input bar hidden or disabled — and then, from any other terminal:

```bash
echo 'hello' | pi remote <session-id>
```

lands in that session as a prompt. On entering the mode, the exact command to pipe into is copied to the clipboard, so there is nothing to retype.

### What exists already

There is no cross-session inbox or forwarding transport in this configuration. A future implementation should start from Pi's supported RPC interface rather than introduce an unacknowledged file-polling protocol.

### The correct version

RPC. `pi --mode rpc` accepts JSON commands on stdin, so a session started in RPC mode can be driven properly rather than poked through a file — with real acknowledgement, real errors, and no polling delay. The gap is that RPC mode and the interactive TUI are different modes today: you get one or the other, not a TUI session that also listens on a pipe.

Bridging that is the actual work, and it is the same bridge [remote sessions](#remote-sessions) needs. Doing `/remote` through RPC first would make the remote case mostly free.

### Deliberate design points

- **Clipboard on entry** — the mode is useless if you have to look up your own session id. Copying the full command is the difference between a feature and a party trick.
- **Hiding the input bar** is the point, not decoration: it makes the state unambiguous, so you do not type into a window that is no longer listening to you.
- **Receive-only is a safety property.** Anything that can pipe into a session can start a turn that spends money, so the inbox path should stay per-session and unguessable, and `/limit` should apply to piped prompts exactly as it does to typed ones.

## Remote sessions

**Want:** connect to a Pi session on another machine from the local editor — the same `Ctrl+Alt+S` picker, but the list includes sessions on other hosts, and choosing one attaches to it.

### What already works today

Two things get partway there and cost nothing:

- **`ssh host -t tmux attach`** — a full remote Pi in a tmux pane. It is a *terminal* on the other machine, not integration: local `/stats` and `/dash` know nothing about it.
- **A shared `sessionDir`** — `sessionDir` in `settings.json` (or `--session-dir` / `PI_CODING_AGENT_SESSION_DIR`) accepts any path, so pointing several machines at one synced directory makes remote transcripts *resumable* locally. Not attachable: resuming a session another machine is live in would have two writers on one JSONL.

### The three real designs

| Approach | How | Cost |
| --- | --- | --- |
| **Resume-only** | Sync `sessionDir` between hosts | Nearly free; no live attach, and needs a lock to stop two hosts writing one file |
| **Drive over RPC** | `ssh host pi --mode rpc`, local TUI as the client | Genuine remote sessions; needs an RPC client wired to the local UI. `--mode rpc` speaks JSON over stdin/stdout, so SSH is the whole transport |
| **Remote tools only** | The `ssh.ts` pattern — read/write/edit/bash execute on the remote, the session stays local | Smallest useful step; the conversation, cost, and context stay on this machine |

`--mode rpc` over SSH is the one that actually delivers what is wanted. Pi already ships an RPC client (`rpc-client.ts`) for exactly this shape of embedding, so the work is wiring it to the local TUI rather than inventing a protocol.

### Blocker worth knowing about

There is no discovery. Pi has no daemon and no socket, so nothing enumerates "sessions on host X" without shelling in and listing the remote `sessionDir`. Any picker starts with an explicit host list.

### Knock-on effects

- [`/stats`](./stats.md) and [`/gc`](./housekeeping.md) assume one local agent directory and would need a host dimension.
- Credentials stay per machine — a remote session uses the remote host's `auth.json`, which is a feature, not a gap.
