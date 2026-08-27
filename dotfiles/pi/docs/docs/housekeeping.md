---
title: /gc
---

# `/gc`

**Pi does not garbage-collect sessions.** Transcripts, exported HTML, shell logs, and legacy improver conversations accumulate in the agent directory until something removes them. `/gc` is that something.

```
/gc              what is on disk, per store, with the oldest entry
/gc dry 30       what /gc 30 would delete, without deleting
/gc 30           delete sessions and logs older than 30 days, after confirming
```

```
Pi storage in /home/alex/.pi/agent
  sessions     9.9M    21 files  oldest 94d
  improve      0B       0 files
  shell-log   12K       3 files  oldest 2d
  notes       4.0K      1 files  oldest 1d
  packages     83M    1204 files
  total        93M
```

## What is prunable

| Store | Pruned by `/gc <days>` |
| --- | --- |
| `sessions` | Yes — `.jsonl` transcripts and exported `.html` |
| `improve` | Yes — legacy conversations and logs from the former separate-session `/improve` |
| `shell-log` | Yes — [`!` command logs](./shell-log.md) |
| `notes` | **No** — hand-written, not regenerable |
| `packages` | **No** — installed npm packages; use `pi remove` |

Deletion asks for confirmation and is not undoable, so `dry` exists. Anything the agent still has open is skipped rather than force-removed.

## Session space in the UI

The same figures are a section in [`/dash`](./dashboard.md), so disk is visible without running a command. `packages` is usually the largest store by a wide margin and is not something `/gc` should touch — it is dependencies, not history.
