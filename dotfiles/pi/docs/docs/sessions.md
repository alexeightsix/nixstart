---
title: Sessions
---

# Sessions

## Starting Pi

Launching bare `pi` starts a new session immediately, with no separate startup chooser. Use `pi --resume` when the intent is to continue an existing session; other explicit session, mode, fork, and prompt arguments pass through unchanged.

## Jumping between sessions

Sessions are switched **in place** — same Pi process, same window, no restart. `Ctrl+Alt+S` opens the session picker (the same list as `/resume`), you pick one, and the conversation is replaced under you.

It filters as you type, telescope-style, and inside the picker:

| Key | Action |
| --- | --- |
| `Ctrl+P` | Toggle full paths |
| `Ctrl+S` | Toggle sort order |
| `Ctrl+N` | Show only named sessions |
| `Ctrl+R` | Rename |
| `Ctrl+D` | Delete |

Name a session with `/name <name>` so it is findable later. `Ctrl+Alt+N` starts a new one.

## Forking

`Ctrl+Alt+F`, or `/fork`, opens the user-message branch-point picker. Choosing a point creates a new session without replacing the current one, splits the current tmux pane to the right, and starts the fork there as `Copy of <current session name>`. Focus remains in the original pane so the two branches can proceed independently. The action requires tmux and reports that requirement before creating a fork when Pi is running outside it.

Because interrupt has been moved off `Escape` (see [Keybindings](./keybindings.md)), a plain **double-Escape opens the same fork flow** — `doubleEscapeAction` is set to `fork` rather than the default `tree`.

`/btw <task>` launches a writable background child agent as a side quest from the current session and returns immediately, without forking the session or opening a tmux pane. Before launch it asks which context to use — the parent conversation, no conversation, or another saved session — and then which configured model to use. If the command has no task text, it asks for the task too. Parent or selected-session context is copied into the child's one-off prompt; the child never writes to that session file.

The child uses the current working directory, runs without session persistence, and may edit files. A statusline count shows running side quests; completion is posted back into this conversation as a compact result without automatically starting another model turn. `/background` is not an alias.

This is deliberately separate from `/fork`: `/btw` delegates work while the current conversation continues; `/fork` forks the session and opens the resulting branch in a right-hand pane.

`/tree` (`Ctrl+Alt+T`) navigates within the current session's branches instead of creating a new one. `/clone` duplicates the active branch in the current pane.

## Interrupting

Interrupt is `Ctrl+Escape`, never a bare `Escape`. This is deliberate: a stray `Escape` should not kill a long turn.

## Where sessions live

`~/.pi/agent/sessions/<project-slug>/<timestamp>_<uuid>.jsonl`, one JSONL file per session. Every user message, assistant message, tool call, and tool result is appended as it happens — the full input and output log already exists without any extra logging setup.

Read one directly, or export it:

```bash
pi --session <path> --export session.html
```

## Compaction

Automatic. Configured in `settings.json`:

```json
"compaction": {
  "enabled": true,
  "reserveTokens": 32768,
  "keepRecentTokens": 30000
}
```

It triggers on context overflow, or proactively as the window fills. `/compact [prompt]` forces it with optional instructions, and the [statusline](./statusline.md) colours the remaining context so you can see it coming rather than be surprised by it.

After every successful compaction, Pi automatically sends a follow-up that reconstructs the active branch, reconciles it with the current worktree, briefly states the recovered context, and immediately continues the next unfinished step. Persisted sessions are followed through parent IDs rather than JSONL append order; ephemeral sessions continue from the compaction summary and live context.

Compactions are counted in [`/stats`](./stats.md). A session that has compacted several times is one where the model has lost detail it once had — worth knowing when its answers start drifting, and a signal to fork rather than keep going.

## Managing sessions

Everything here is built into Pi and needs no extra machinery:

| Want | Use |
| --- | --- |
| Keep going but shrink the context | `/compact`, or let it fire automatically |
| Keep the context but branch the work | `/fork`, or double-Escape |
| Go back to an earlier point in this session | `/tree` (`Ctrl+Alt+T`) |
| Duplicate the current branch | `/clone` |
| Switch to a different conversation | `Ctrl+Alt+S` |
| Find it again later | `/name <name>` |
| Reclaim disk | [`/gc`](./housekeeping.md) |
