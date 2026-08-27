---
title: /stats
---

# `/stats`

An analytical breakdown of the session. The [statusline](./statusline.md) shows running totals; this shows the composition.

```
/stats
/costs    chronological cost and elapsed time for every model and tool step
```

```
Session  1h 12m elapsed · 18m 04s working · 34 turns · 96 messages
Spend    ↑1.20M  ↓48.2k  $4.181
Cache    71% of input served from cache
Context  184.2k / 400.0k (46%) · 215.8k left

By model
  openai-codex/gpt-5.6-sol    21 turns  ↑820.1k  ↓31.4k  $2.104  85%
  opencode-go/kimi-k3           5 turns  ↑71.4k   ↓4.0k   $0.375  15%

Tools
  read   64
  bash   38
  edit   19
```

## Cost history

`/costs` opens a scrollable, branch-scoped history rather than printing a long table into the transcript:

```text
 #   time      step                         elapsed    tokens                 cost      total
 1   07:36:55  model gpt-5.6-sol             14.4s    ↑43.2k ↓1.1k r620      $0.078    $0.078
 2   07:36:55  tool  todo_write                1ms    —                       $0.000    $0.078
 3   07:37:09  model gpt-5.6-sol             14.6s    ↑44.1k ↓980 r510       $0.079    $0.157
```

A **model step** is one assistant response in Pi’s agent loop. It carries the provider-reported input, cache, output and reasoning tokens and is the only kind of step with model cost. A **tool step** is one local tool execution; it shows elapsed wall time and `$0` because providers do not price local tool calls separately—the model step that requested the call already contains the billable tokens.

New timings are measured from Pi’s message and tool lifecycle events and persisted as custom entries in the session itself. Existing history from before this feature is still shown using adjacent message timestamps; an estimated duration is prefixed with `~`. The cost itself is never estimated: it always comes from the recorded provider usage. No parallel usage file can drift away from the transcript.

The final column is cumulative model spend on the current branch. Forking or moving in `/tree` therefore changes the visible history consistently with `/stats` and the statusline.

## What each part measures

**Session** — wall-clock since the session started, versus time actually spent inside turns. The gap is thinking time on your side, not the model's.

**Spend** — total input (including cache reads and writes) and output tokens, and dollars. Costs come from each provider's reported usage rather than a second local estimate.

**Cache** — the share of input tokens served from cache. A number that collapses after a model switch is expected: caches are per-provider, so crossing a boundary starts cold. See [Models](./models.md#context-is-shared-across-providers).

**Context** — the same figure the statusline shows, with the raw numbers rather than a percentage. When the session has compacted, the count appears here too: compaction is lossy, so a session on its third compaction is one whose earlier detail is gone.

**By model** — the point of the command. Turns, tokens, cost, and share of total spend per model, sorted by cost. This is what tells you whether the models you select are earning their place.

**Tools** — call counts by tool, from `tool_execution_start`.

## Scope

Figures describe the **current branch** of the conversation. After a `/fork` or a jump in `/tree`, the token and model tallies reflect the branch you are on; timing and tool counters are per-process and cover the whole session regardless of branch.
