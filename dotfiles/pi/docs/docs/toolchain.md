---
title: Agent toolchain
---

# Agent toolchain

Pi inherits the machine's user-level `PATH` and keeps its native file tools intact. Tool choice follows this precedence:

1. Use a native structured tool when it is the more precise or token-bounded interface.
2. Use a modern command-line primitive when shell execution is needed.
3. Avoid a slower or noisier legacy fallback when an installed modern tool fits.

## Preferred primitives

| Need | Preferred interface |
| --- | --- |
| Targeted file read | Pi `read` with an offset/limit |
| Content search | Pi `grep` when available; otherwise `rg` |
| File discovery | Pi `find`/`ls` when available; otherwise `fd` or `rg --files` |
| Semantic navigation | Pi `lsp` |
| Independent read-heavy investigation or review | Pi `subagent` |
| Exact edits and file creation | Pi `edit` and `write` |
| JSON | `jq` |
| YAML | `yq` |
| Diff inspection | `git diff --no-ext-diff --no-color`; `delta --paging=never` when its formatting helps |
| Patch application | Pi `edit`, `git apply`, or `patch`, according to the input |
| Processes | `ps` and `pgrep` |
| HTTP | `curl` |
| Syntax-aware search | `ast-grep` when text search cannot express the structure safely |

The native `read`, `grep`, `find`, `ls`, `edit`, and `write` tools are not replaced with shell commands for consistency. In particular, a bounded `read` is preferable to printing a whole file through `cat` or `bat`. Subagents use the same read-only native set plus `lsp` and bounded Bash; the parent owns edits.

Pi's non-interactive Bash calls do not import the human shell's alias files. Canonical commands therefore retain their normal semantics, and agent behavior does not depend on machine-specific shortcuts.

Agent-run Git commands receive `GIT_EDITOR=true`, `GIT_SEQUENCE_EDITOR=true`, and `GIT_MERGE_AUTOEDIT=no`, so an unexpected editor cannot hang a tool call. The interceptor blocks `--no-verify`; hook failures must be fixed or brought to the user rather than bypassed. In a workspace containing an ancestor `ship.sh`, direct `git commit` and `git push` are also blocked in favor of that repository's shipping workflow.

Pi 0.84.1 also ships native `grep` and `find` tools. Its native `grep` already runs ripgrep with line numbers, no colour, `.gitignore` handling, and match/byte limits. No third-party grep/find extension is installed: the available wrappers duplicate this behavior, rewrite shell commands unexpectedly, or add a larger interface without a demonstrated advantage.

## Shell output discipline

Shell calls should make their output proportional to the question:

- constrain paths, globs, match counts, context lines, and line ranges;
- keep ripgrep's normal ignore handling, including `.gitignore`, and include hidden or ignored files only when the task requires them;
- prefer `rg --files`, `fd`, or a shallow `tree` over recursive directory dumps;
- request JSON or another machine-readable format when a downstream filter will consume it;
- disable colour and pagers in captured output (`--color=never`, `--no-color`, `--no-pager`, `--paging=never`) while preserving normal interactive presentation;
- use `timeout` for commands that may wait indefinitely and non-interactive flags for network, package, and Git operations;
- refine a search after a limit is reached rather than immediately printing a larger result set.

Generated and dependency directories remain a project concern. Normal searches rely on repository ignore files and native ripgrep behavior rather than a global ignore file that could hide legitimate content in another codebase.
