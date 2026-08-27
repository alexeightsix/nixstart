---
title: Code rendering
---

# Code rendering

Code in the interactive transcript uses the Rose Pine syntax palette instead of one flat tool colour.

## Bash tool calls

The command shown at the top of every `bash` tool card is highlighted as shell code. A mixed-language heredoc is split at its delimiter: the shell invocation and closing delimiter remain Bash, while the body uses its own grammar.

```bash
python3 - <<'PY'
from pathlib import Path
print(Path.cwd())
PY
```

The inner language is resolved, in order, from:

1. the interpreter before the heredoc (`python3`, `node`, `ruby`, `php`, `bash`);
2. the file receiving a `cat` heredoc (`config.json`, `main.go`, `query.sql`, and other known extensions);
3. a conventional delimiter such as `PY`, `JS`, `TS`, `GO`, `SQL`, `JSON`, `HTML`, `CSS`, or `SH`.

Unknown heredocs remain Bash-coloured rather than being guessed incorrectly. Timeouts, output, truncation, timing and execution are still Pi’s built-in Bash behavior; only the command renderer changes.

Each Bash card carries a muted `Ctrl+Alt+C copy` hint. That shortcut, or `/copy-code`, copies the most recently rendered Bash command. If a newer assistant message contains a fenced code block, its most recent fence is copied instead. Pi’s TUI exposes drag-selection and hyperlink clicks but no extension-level click or double-click regions, so the visible keyboard action is the one-step copy affordance.

## Markdown code fences

A fence with an explicit language keeps it. An unlabelled fence is labelled for rendering only when its contents match a conservative language signature. The stored message and model context are unchanged.

Supported inference covers common shell, Python, JavaScript/TypeScript, Go, Rust, SQL, JSON, HTML, CSS and YAML forms. If no signature is strong enough, the fence stays plain. A wrong confident colour is worse than no colour.

## File tool cards

Read output and edit diffs derive their source language from the file extension. In an edit diff, the gutter and `+`/`-` markers communicate the patch while source tokens keep the Rose Pine syntax palette. Diff colouring does not flatten an entire added or removed line into one foreground colour.

Files without a known grammar remain plain. Normal command output also remains plain text because stdout can mix logs, tables, diagnostics and several languages in one stream.
