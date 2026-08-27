---
title: Modes
---

# Permission modes

Permission mode controls what the agent is allowed to do and appears in the [statusline](./statusline.md).


Provided by `extensions/permission-modes.ts`.

| Mode | Behaviour |
| --- | --- |
| `all` | Every tool runs unattended. |
| `ask` | Writes and mutating shell commands prompt first. **Default.** |
| `read-only` | Writes and mutating shell commands are refused outright. |

Read-only work never prompts in any mode. The gate classifies a `bash` call by splitting it on shell separators and requiring *every* segment to be recognisably read-only — a known read-only binary (`ls`, `rg`, `jq`, …) or a reporting subcommand (`git status`, `gh pr view`, `kubectl get`, …). A redirection to anything other than `/dev/null`, a `sudo`, or an unrecognised binary makes the whole command mutating.

```
/perm              pick a mode
/perm all          set one directly
Ctrl+Alt+A         cycle
pi --perm all      start a run in a given mode
```

At the prompt, **Allow all this session** switches the mode to `all` for the rest of the session.

The mode is per-session by design. A permissive mode is never inherited from a run you have forgotten about, and it is never written back to `settings.json`.

For a review or planning-only task, use `read-only`; for a durable execution plan, use the structured [`todo` tools](./todo.md). The former plan-mode extension was removed because it duplicated both mechanisms while adding a second planning state and command surface.
