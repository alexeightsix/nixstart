---
sidebar_position: 1
slug: /
title: This is the source of truth
---

# Pi, as configured here

This site documents the [Pi](https://github.com/badlogic/pi-mono) instance defined in `~/kickstart/dotfiles/pi`. Pi is the editor; this directory is its configuration; this site describes what that configuration does.

**The documentation is the source of truth, not the code.** When a page here and the config disagree, the config is the thing that is wrong.

## The working order

1. A request comes in.
2. Check the documentation.
3. If the request changes behaviour, update the documentation first.
4. Then change the code to match.

Every documentation edit is logged in the [changelog](./changelog.md) with the reason for it. What changed is recoverable from git; why it changed is not.

This order is enforced by `APPEND_SYSTEM.md`, which is appended to Pi's system prompt for every session.

## Coding-first operating policy

Pi is a coding assistant unless the user explicitly asks for another kind of work. A clear request is enough to begin: Pi uses the current repository and its local instructions as context, inspects before editing, makes the smallest coherent change, and verifies it with the project's own checks.

Pi asks a question only when a missing requirement blocks correct work, an irreversible choice needs consent, or a request plausibly belongs to a different project. It does not repeat project context the user already supplied or require a startup questionnaire. Cross-cutting work such as documentation, tests, CI, dependencies, deployment, and development tooling is normal coding work.

For substantial independent investigation or review, Pi can use [provider-generic subagents](./subagents.md). The parent remains responsible for decisions, edits, and verification.

## What is where

| Path | What it is |
| --- | --- |
| `settings.json` | Model defaults, theme, compaction, retry, packages |
| `keybindings.json` | Key overrides — see [Keybindings](./keybindings.md) |
| `mcp.json` | MCP servers — see [MCP](./mcp.md) |
| `APPEND_SYSTEM.md` | The working order above, appended to every session's system prompt |
| `themes/rose-pine.json` | The theme |
| `extensions/` | Local extensions: coding tools, subagents, statusline, permission modes, safety gates, and focused workflow helpers |
| `skills/` | Configuration-owned `auto-push`, `demo`, `pr-review`, `source-of-truth`, `tldr`, and `wrong-number`; user-global `code-review`, `diagnosing-bugs`, `codebase-design`, `find-skills`, `git-guardrails-claude-code`, and `grill-me` live under `~/.agents/skills/` |
| `link.sh` | Symlinks all of the above into `~/.pi/agent` |
| `docs/` | This site |

Every tracked resource in `~/.pi/agent` is a symlink back into this directory. Runtime state — sessions, credentials, the model catalogue, installed npm packages, and explicitly external integrations such as herdr — stays in `~/.pi/agent` and is deliberately **not** tracked. Third-party skills have one canonical installation under `~/.agents/skills`; duplicate Pi-specific links are not installed.

## What is not tracked, and why

`~/.pi/agent/auth.json` holds OAuth tokens and API keys. It is never copied into this repository. Provider credentials are established once per machine with `/login` inside Pi, or by the provider's own CLI. See [Models and providers](./models.md#credentials).
