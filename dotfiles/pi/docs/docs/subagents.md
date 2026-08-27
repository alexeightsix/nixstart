---
title: Subagents
---

# Subagents

Pi exposes one provider-generic `subagent` tool for bounded coding investigation and review in isolated context windows. Each task starts a separate `pi` process with the parent session's selected model and thinking level.

## When to delegate

Use a subagent when work is independent and read-heavy: locating an implementation, tracing a subsystem, comparing several approaches, or reviewing a finished diff. Keep trivial lookups in the parent. The parent owns decisions, edits, integration, and final verification, so parallel children cannot overwrite one another or report unverified work as complete.

A delegated task is self-contained. The child receives only its task, working directory, the normal project context files, and a short read-only coding brief; it does not receive the parent conversation. The parent therefore supplies the relevant goal, constraints, and expected result instead of referring to “the code above.”

## Tool contract

The tool accepts either one task or up to four independent tasks:

```text
subagent({ task: "Trace how authentication errors reach the HTTP response" })
subagent({ tasks: [
  { task: "Find the session persistence boundary" },
  { task: "Review the current diff for concurrency bugs" }
] })
```

Each child is restricted to `read`, `grep`, `find`, `ls`, `bash`, and `lsp`, with permission mode forced to `read-only`. Semantic questions use the configured [LSP tool](./lsp.md); lexical searches use the native search tools or bounded shell commands. Tasks run concurrently, abort with the parent tool call, and return one clearly labelled result per task. Output is capped before entering parent context; the full child transcript is intentionally not persisted as another session.

## Provider and cost

Subagents are not tied to Claude, Anthropic, or another external agent CLI. They run the installed Pi binary with the model and thinking level already selected in the parent. Their provider-reported usage is attached to the tool result so Pi's normal session totals include delegated work.
