---
title: Testing
---

# Testing

Three layers, all runnable now.

```bash
./tests/e2e.sh          # everything that costs nothing
./tests/e2e.sh --paid   # also real turns that spend tokens
node --experimental-strip-types --test tests/*.test.ts $(find extensions -name '*.test.ts')
```

Unit files live in `tests/` **and** beside the code they cover inside `extensions/`. `e2e.sh` collects both, because a test file that no command collects is the same as no test at all. The runner strips types rather than compiling them, so extension code it must load avoids TypeScript syntax that has no JavaScript form — constructor parameter properties in particular. Pi itself transpiles extensions through jiti and accepts them, which is exactly why the restriction has to be written down: the failure appears only in the test run.

## Units

The TypeScript `*.test.ts` files use plain `node:test` with no test-framework dependencies. They cover behavior where being wrong is **silent**:

- The bash classifier. A false "read-only" skips the permission prompt entirely, so the table covers pipelines, redirections, `sudo`, `git status` versus `git commit`, and unrecognised binaries (which must gate, not pass).
- Limit parsing. `$5` read as 5 tokens blocks instantly; `5` read as `$5` lets a session spend for hours. Both failures are quiet, so there is an explicit test that the two never agree.
- Kill-time parsing. A clock time already past today must roll to tomorrow, or `/kill 09:00` typed at 10:00 fires immediately.
- LSP message framing, workspace/server selection, position conversion and compact result formatting. The end-to-end suite also checks that both configured server binaries are runnable.
- Status-line skill recognition, three-item recency/deduplication, and reservation of the LSP indicator for the far-right side.
- TLDR snapshot boundaries, meaningful-change detection, cache restoration/reuse, and summarization prompt structure.
- Subagent JSON-event parsing, output caps, argument construction, and failure reporting without spending tokens.

This is only testable because the logic lives in `lib/`, which imports nothing from pi. Extensions import from there, so the tests cover shipped code rather than a copy. **Put new pure logic in `lib/`.**

The e2e suite also invokes selected extension commands through a real Pi RPC process when a load check cannot reach the risky code. The `/dash` probe, for example, catches a command using a context method that does not exist before the overlay can render. These probes do not replace tmux inspection — they only prove the real command reaches its renderer without an API error.

`lib/` is symlinked into the agent directory alongside `extensions/`, because relative imports resolve from the symlink location, not the real path.

## End to end

`tests/e2e.sh` runs against the real binaries — no mocks, because the failures worth catching only happen against the real thing:

| Check | Catches |
| --- | --- |
| Every JSON config parses | A trailing comma that stops pi booting |
| The global prompt contains the coding-first policy and wrong-project guardrail | Accidental restoration of the startup questionnaire or removal of targeted wrong-project confirmation |
| `link.sh` twice against a temp `PI_CODING_AGENT_DIR` | Non-idempotent linking |
| Every link resolves, and into this repo | Dangling or stray symlinks |
| `pi --list-models` stderr | **Any extension failing to load** |
| `pi auth check` per provider | An expired credential |
| `gopls`, `tsgo` version commands | A missing or broken configured language server |
| Every TypeScript `*.test.ts` file | Pure logic plus stateful queue/lifecycle regressions |
| Real RPC invocation of `/dash` | Command-time API drift before the overlay renderer opens |

`--paid` adds one real turn through the configured default model. The free tier still verifies extension loading and provider readiness without spending tokens.

The extension-load check is the highest-value line in the file. Load errors print to stderr before any model call, so it catches a broken extension for free.

## Look at it in tmux

Headless runs prove an extension **loads**. They do not prove it **looks right**.

```bash
tmux capture-pane -p -t <pane>
```

Several defects here were invisible headlessly and obvious in a capture: a spinner flush against the terminal edge, a duplicated working indicator, an MCP count printed twice. Anything that renders — statusline segments, widgets, overlays, dialogs — gets looked at before it is called done. This rule is in `APPEND_SYSTEM.md`, so an agent working here follows it too.

## What is not covered

Prompt contracts are covered structurally. The free e2e suite checks that `APPEND_SYSTEM.md` retains its required coding-first and wrong-project instructions, rejects the retired startup questionnaire, and verifies that prompt-bearing skills and context files are installed. Unit tests assert the exact required structure of generated prompts such as TLDR summaries and post-compaction continuation.

What is not automated is judgement: no string assertion can prove that a model follows those prompts well. Behavioral prompt quality is validated through real use, and regressions in a specific required instruction must add a focused structural assertion.

Interactive flows — the `/dash` overlay and permission dialogs — are verified by tmux capture rather than automation. Driving the TUI programmatically is possible through `--mode rpc` and is the obvious next step if these start regressing.
