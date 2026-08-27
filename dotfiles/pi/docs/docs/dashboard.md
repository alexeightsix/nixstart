---
title: /dash
---

# `/dash`

One overlay showing everything the agent currently has. `↑↓` scrolls, `Esc` closes.

```
/dash
```

| Section | Shows |
| --- | --- |
| model | Active model, its context window and max output, thinking level, how much of the window is used and how much is left |
| switchable models | Every model in the `Ctrl+P` cycle with its window size; `●` marks the active one |
| where | Working directory, and whether the project is trusted |
| mcp | Every configured server, and which are loaded |
| tools | Every tool currently enabled |
| recent skills | The two newest unique skills used in this session, plus `+N more` when earlier skill history exists |
| spend | Session tokens and cost, with a pointer to [`/stats`](./stats.md) for the per-model split |

## The MCP segment

`/dash` also owns the statusline's MCP indicator:

```
mcp 2/5 figma, linear
```

Loaded out of configured, then the names of the loaded ones. Grey at `0/n`, green once something is up.

MCP servers here are `lifecycle: lazy` — nothing connects until a tool from that server is called — so `mcp 0/5` at rest is correct, not a fault. A server counts as loaded exactly when something first calls into it.

## Why an overlay rather than a widget

The information is wide, occasionally long, and only wanted on demand. A permanent widget would cost rows on every screen to answer a question asked once an hour; the [statusline](./statusline.md) already carries the parts worth watching continuously.
