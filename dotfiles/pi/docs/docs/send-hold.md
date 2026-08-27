---
title: Send hold
---

# Send hold

The **first prompt in a new, empty session sends immediately**. After that, submitting a prompt while Pi is idle holds it for **5 seconds**, during which you can take it back. Typing another prompt during that hold appends it to a **FIFO queue** — it never replaces or drops the prompt already waiting.

```
:w!          submit this prompt and flush the held queue immediately
/abort       discard the most recently queued message
/abort all   discard every held message
```

In the [Vim prompt](./vim-prompt.md), EX `:w` submits through the normal hold. EX `:w!` submits the current prompt and immediately releases it plus every message already held, in FIFO order. There is no `/send` command.

While messages are held, a widget sits directly above the editor — where you are already looking after pressing Enter — showing the oldest message's countdown, its preview, and how many more are behind it:

```
⏳ queued — sending in 3s    :w! to send now    /abort to cancel
   have a look at the auth middleware and tell me…
   …and 2 more queued behind it
```

The [statusline](./statusline.md) carries a compact `hold 3s +2  /abort` at the same time. Both remain until the queue is empty.

When the oldest message's hold expires, it starts a turn. The rest remain queued in typing order; while that turn runs the widget says `sending after this turn` rather than pretending a zero-second countdown is still active. After the turn settles, the next due message starts.

`:w!` clears the remaining countdown for **every** held message, appends its current prompt, and starts the flush immediately. Pi still starts only one model turn at a time, so later messages leave in FIFO order as each preceding turn settles. Nothing is billed and nothing enters the session until its message leaves the hold queue — an aborted message leaves no trace in the transcript.

## Why a delay rather than an undo

You usually know a prompt was wrong within a second or two of pressing Enter — before the model has done anything, and long before it has finished. Interrupting after the fact leaves half-applied work to clean up. Holding the send avoids creating the mess instead of unwinding it.

Five seconds is long enough to catch a wrong prompt and short enough not to feel like waiting. `:w!` exists for when you are certain.

## Aborting queued and running work

A plain `/abort` always removes the **most recently typed held message**, leaving earlier messages in the FIFO queue. This makes the prompt you just realised was wrong the first one taken back. Use `/abort all` when none of the held work should run.

Only when the hold queue is empty does `/abort` fall back to interrupting the turn in progress — the same thing `Ctrl+Escape` does:

| When | What `/abort` does |
| --- | --- |
| One or more messages held | Discards the most recent one. Never sent, never billed. |
| Release preflight already started | Says it is leaving the queue; `/abort all` clears the release as the recovery path. |
| No message held, turn running | Interrupts it, like `Ctrl+Escape`. |
| Neither | Says there is nothing to abort. |

Interrupting a running turn does **not** revert files the agent already changed. Use git for that — the change is real work that partially happened.

## TUI only, and session-scoped

Only prompts typed in the interactive TUI are held. `--print`, `--mode json`, and `--mode rpc` prompts go straight through: those modes have no local editor in which to use the countdown, and RPC already has its own accepted/queued response contract. This also preserves image attachments sent by RPC clients rather than reducing them to held text.

The queue belongs to one live session. Switching, forking, reloading, or quitting clears its timer and widget before the old extension runtime is torn down; held work never leaks into a replacement session. A genuinely empty replacement session gets the same one-time first-prompt bypass. Resuming, reloading, or forking a session that already has conversation history does not reset the bypass.

## Interaction with active turns and other modes

- Input typed while a model turn is already running is **not held**. It goes straight to Pi's own steering queue so a five-second delay cannot get in the way of steering active work.
- Slash commands are never held; they run immediately. Otherwise `/abort` itself would sit in the queue.
- A hard [`/limit`](./guardrails.md) is checked again when each held message is released. If the preceding turn crosses the cap, the next held message remains queued and paused until the limit is raised or lifted.
