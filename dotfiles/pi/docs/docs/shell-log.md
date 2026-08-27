---
title: Shell log
---

# Shell log

Typing `!` in front of a command runs it as bash without involving a model:

```
!git status
!!rm -rf node_modules
```

This is Pi's own feature, and the result already goes into the model's context so it can see what you did. The double-bang form, `!!`, runs the command but keeps it **out** of the model's context.

What Pi does not do is keep a record. This config adds one.

```
/shell-log         this session's commands
/shell-log path    where the file is
```

## Per session

A new log file per session, under `~/.pi/agent/shell-log/`, named by timestamp and by why the session started (`startup`, `resume`, `new`, `fork`). Switching sessions starts a fresh log rather than appending to the previous conversation's, so a log always matches the conversation it belongs to.

Each entry records the timestamp, the working directory, and the command. Commands run with `!!` are marked `[hidden from model]` — worth recording precisely because they explain a gap in what the model knows.

Output is not duplicated into the log; for the visible commands it is already in the session transcript.

## Pruning

Shell logs are pruned by [`/gc`](./housekeeping.md) along with session transcripts.
