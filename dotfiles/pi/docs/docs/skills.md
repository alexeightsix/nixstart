---
title: Skills
---

# Skills

Skills are on-demand instruction packages. Configuration-owned skills live in `skills/` here and are linked into `~/.pi/agent/skills/`. User-global skills installed into `~/.agents/skills/` are discovered without another Pi-specific copy.

The user-global allowlist is `code-review`, `diagnosing-bugs`, `codebase-design`, `find-skills`, `git-guardrails-claude-code`, and `grill-me`. The first five are agent-invocable; `grill-me` is manual-only. Configuration-owned and package-provided skills are independent of this allowlist.

`enableSkillCommands` is on, so each skill is also a slash command.

## `auto-push`

```text
/skill:auto-push /absolute/path/to/repository
```

Starts a one-second Git sync loop for the target directory. Its launcher first requires an existing tmux server; when tmux is not already running it exits successfully without creating a server or changing the target. It installs the worker at `${XDG_STATE_HOME:-~/.local/state}/pi/auto-push.sh` when that file is absent, then starts it in a detached tmux session named `automations`. A later invocation adds a window to the existing session rather than replacing another automation.

The worker runs `git add .`, commits staged changes as `sync`, and pushes each successful commit. The launcher reports the worker's exact pane because the configured muxbar sidebar may become the window's active pane after startup; verification captures the reported worker pane rather than whichever pane is active. The skill is manual-only because invoking it grants an ongoing process permission to commit and push future changes without another prompt.

## `grill-me`

```
/skill:grill-me
```

This is the canonical upstream-derived copy installed at `~/.agents/skills/grill-me`; `.agents/.skill-lock.json` retains its provenance. This repository must not link a second copy into `~/.pi/agent/skills/`.

It contains its relentless design interview directly rather than dispatching to another global skill: map the subject as a decision tree and ask the current frontier of questions in rounds. `disable-model-invocation: true` means it only runs when you ask for it.

## `pr-review`

```
/skill:pr-review
/skill:pr-review 1234
```

Reviews a PR, a branch, or the current diff. Correctness first — wrong values, observable partial state, unhandled inputs, lost errors, leaked resources, injection, contract drift with callers. Reuse and simplification findings come second and are grouped separately so they read as optional.

It is instructed to try to disprove each finding before reporting it: construct the triggering input, check whether a guard already makes it impossible, re-read the code rather than the diff. Findings that cannot be made concrete are dropped rather than hedged.

## `demo`

```
/skill:demo /dash
```

Shows a feature working instead of describing it: chooses the natural medium, drives the real thing, captures evidence, and leaves it available to inspect. Asking “show me this working” can load the same skill automatically. The separate `/demo` wrapper is intentionally absent because it duplicated normal skill invocation.

See [/docs and live demos](./docs-command.md).

## `tldr`

```text
/skill:tldr
```

Summarizes the active session branch into goals, decisions, progress, open questions, and next steps. The result is cached in branch-scoped session state: invoking it again without any new meaningful conversation returns the existing TLDR without another summarization request. Cache misses use long provider prompt-cache retention.

The skill is user-invoked, so its instructions add no permanent context load. See [Session TLDR](./tldr.md) for snapshot and cache semantics.

## `wrong-number`

```text
/skill:wrong-number
```

Treats the user request immediately before the invocation as a message intended for another agent. It rewrites that request as a self-contained handoff prompt, adding only conversation context needed to preserve references, constraints, decisions, and desired output, then copies the prompt to the system clipboard. The transcript receives a short confirmation rather than a duplicate of the prompt.

The skill is user-invoked because recognizing a misaddressed request is the user's decision; its instructions add no permanent context load.

## Controlling model invocation

`/toggle-skills` opens a searchable overlay of global, user, and project skills. Space switches the selected skill between **agent-invocable** and **manual-only**; `Ctrl+S` applies all changes and reloads Pi, while Escape cancels.

Manual-only mode writes `disable-model-invocation: true` to the skill's existing frontmatter. Switching back removes only that field. The command refuses to modify malformed, frontmatter-free, or non-writable skills and shows their diagnostics instead. Because canonical third-party skills are edited in place, their package manager may replace this preference during an update.

## Adding one

Create `skills/<name>/SKILL.md` with `name` and `description` frontmatter, then re-run `link.sh`. Directories containing a `SKILL.md` are discovered recursively.

To borrow skills from another harness, add its directory to `settings.json` as an explicit additional skill path. Keep one canonical installation so two discovered copies cannot collide. Third-party skills under `~/.agents/skills` are not mirrored into `~/.pi/agent/skills`; Pi discovers the canonical directory directly.

## `source-of-truth`

```
/skill:source-of-truth
```

Bootstraps a project onto the method this configuration was built with: documentation as the specification, a requirements ledger, a changelog that records *why*, and verification rules.

Run it in a project root and it sets up a Docusaurus site, the three standing pages (`intro`, `requirements`, `changelog`), a `.pi/APPEND_SYSTEM.md` binding the working order into every session, and a portable `/docs` command.

It ships two assets:

| Asset | Becomes |
| --- | --- |
| `assets/docs.ts` | `.pi/extensions/docs.ts` — self-contained `/docs`, finds the site by walking up, serves the shared port 3565 and opens the project's changelog by default |
| `assets/requirements.md` | `docs/docs/requirements.md` — the append-only request ledger |

The requirements ledger is the part worth stealing on its own. Rows are added when a request **arrives**, not when it is finished, and `done` requires named evidence — so "did we do everything?" is answered by looking it up rather than remembering.
