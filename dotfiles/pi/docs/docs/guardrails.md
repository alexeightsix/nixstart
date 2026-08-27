---
title: /pause, /limit and /kill
---

# Pause, kill switch and spend limit

Three ways to stop a session running away with your money. They are deliberately different, and `/limit` is the hard budget ceiling.

| | `/pause` | `/limit` | `/kill` |
| --- | --- | --- | --- |
| Stops | Future turns until a time | New turns at a budget | The whole process |
| Active turn | Finishes normally | Finishes normally | Interrupted |
| Session survives | Yes | Yes, fully intact | Saved, but work in progress is lost |
| Reversible | `/pause off` | `/limit off` | No |

## `/pause`

```text
/pause          choose 5m, 15m, 1h, or a custom duration/time
/pause 45m      pause future work for 45 minutes
/pause 17:30    pause until a wall-clock time
/pause off      resume now
```

A pause never interrupts the active turn. Once that turn finishes, ordinary prompts remain in the held FIFO queue and no extension-injected turn starts until the pause expires. Slash commands remain usable. At expiry the queue resumes automatically in its original order; `/pause off` does the same immediately.

The chosen deadline is stored in the session, restored across `/reload` and resume, shown in the statusline, and removed once it expires. The no-argument picker offers **5 minutes**, **15 minutes**, **1 hour**, **Custom…**, and **Cancel**.

## `/limit`

```
/limit $5           block new turns once the session has spent $5
/limit 500k         same, capped on tokens
/limit warn $5      warn at the cap, but keep going
/limit              what has been spent, and what the cap is
/limit off          lift it
```

Accepts `$5`, `500k`, `2M`. A `$` means dollars; a bare number means tokens.

When a hard token limit is reached, the next prompt opens a decision menu instead of disappearing:

1. **Pause until…** — choose a retry time using the `/pause` presets or custom duration; the prompt remains queued.
2. **Switch model and continue** — choose another scoped model, give it the guardrail's built-in redacted handoff recipe and the retained prompt, then continue there. The same token allowance restarts from zero for the new model; earlier branch spend remains visible in `/stats` and `/costs`.
3. **Cancel** — discard that prompt and leave the limit in force.

A dollar limit remains a direct hard block: raising or lifting it resumes immediately. In every case nothing destroys the session, context, or history. Slash commands keep working, so you are never locked out of your own session.

Spend is measured on the current branch, from each provider's reported usage — the same figures behind [`/stats`](./stats.md).

## `/kill`

```
/kill               ask: now, or scheduled
/kill 45m           shut down in 45 minutes
/kill 2h            shut down in 2 hours
/kill 17:30         shut down at a wall-clock time
/kill cancel        call it off
```

`/kill` with no argument asks whether you mean now or later. **Now** confirms first, then shuts down gracefully — the session is saved and resumable, but anything mid-turn is lost. **Scheduled** takes a duration or a time; a clock time already past today means tomorrow.

This exists for unattended sessions. An agent left running with a long task can keep spending for hours; a scheduled kill puts a hard ceiling on that in wall-clock terms, where `/limit` puts one on it in money terms.

## In the statusline

All active guardrails appear in the [statusline](./statusline.md):

```
pause 17:30 (45m)    limit $2.10/$5.00    kill 18:30 (1h45m)
```

The limit readout is dim under 80% of the cap, amber past it, and red once reached. The kill countdown ticks down while the session is idle — which is exactly when an unattended session is burning its schedule down unobserved.
