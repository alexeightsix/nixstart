---
name: tldr
description: Summarize the current session, reusing the cached TLDR when nothing meaningful changed.
disable-model-invocation: true
---

<!-- pi-tldr-skill:v1 -->

Call `session_tldr` exactly once with no arguments. Return no prose before the call. The tool renders the TLDR and terminates the turn, so its result is the completion criterion.
