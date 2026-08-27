---
title: Session TLDR
---

# Session TLDR

`/skill:tldr` produces a concise state-of-the-session summary with goals, decisions, progress, open questions, and next steps.

## Cache behavior

The first request summarizes the active session branch and stores the result as branch-scoped session state. The snapshot excludes TLDR commands, the TLDR skill prompt, TLDR tool calls and results, and the assistant message that presents a generated TLDR.

A later request compares the meaningful conversation snapshot with the stored fingerprint:

- unchanged snapshot — return the cached TLDR immediately, without another summarization request;
- changed snapshot — summarize the current branch again and replace the cache.

The generated summary survives `/reload` and session resume because the cache is a custom session entry. Forks and tree navigation see only cache entries on their active branch.

## Provider caching

Cache misses use the active model with long prompt-cache retention and a stable TLDR-specific session identifier. The full conversation remains an append-only prompt prefix as the session grows, allowing providers that support prompt caching to reuse earlier input. The nested summarization usage is returned by the tool so Pi's session accounting remains complete.

## Usage

```text
/skill:tldr
```

The user-invoked skill calls `session_tldr` once and terminates on its rendered result. Running summarization through a tool keeps nested model usage in Pi's normal session accounting. The full TLDR workflow stays out of the default model context until the skill is explicitly invoked; the active tool contributes only its compact schema description.
