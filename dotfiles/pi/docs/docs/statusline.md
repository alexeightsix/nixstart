---
title: Statusline
---

# Statusline

`extensions/statusline.ts` replaces Pi's built-in footer with one line split by importance and alignment:

```
  ⠹  ●?+~/dev  hold 3s  5.6-sol  ◇high  linear fathom +2 others       OC 100%  CX* 76%  CC 21%  CC2 21%  ↑ 412k ↓ 18k  ↺ 71%  $ 1.87  ◫ 34%/1.0M 660k left
```

Active operational state starts flush at the left edge. The spinner occupies that first cell continuously: a dim static frame while idle and an animated accent frame while a turn runs. Usage and spend form one stable, right-aligned block so their position is easy to scan and does not drift as left-side state changes.

## Left

| Segment | Meaning |
| --- | --- |
| `⠹` | Activity indicator. It rests as a dim static `⠋` while idle and animates in accent color while a turn runs. Pi's own in-chat loader is suppressed so there is exactly one. |
| `●?` | Permission mode. Red `●!` is unattended writes (`all`), gold `●?` asks before writes (`ask`), and green `●–` refuses writes (`read-only`). `+~/dev` shows how far [grants](./modes.md) reach. |
| `hold 3s` | Anything demanding a decision, such as a [held send](./send-hold.md) or [spend cap](./guardrails.md). [Todo](./todo.md) progress stays in its above-editor widget and is not repeated here. |
| `5.6-sol  ◇high` | Active model in a compact stable alias and its thinking level. `◇` ties the value to the input-border colour changed by `Shift+Tab`. |
| `linear fathom +2 others` | Connected MCP servers only, in configured order. At most three names are shown; further connected servers collapse to `+N others`. No MCP segment appears before a server connects, and the old `MCP 0/5` count is not shown. |

Git branch, working directory, elapsed time, and the generic `LSP ✓` loaded marker are omitted from the footer. They remain available through the shell, session transcript, and [`/dash`](./dashboard.md) rather than competing with active state and usage.

## Right

| Segment | Meaning |
| --- | --- |
| `OC 100%  CX* 76%  CC 21%  CC2 21%` | Account usage across every healthy provider in the cached `burn --json` snapshot, ordered from most to least used. `*` marks the Burn provider related to the active Pi model (`openai-codex` → `CX`, `opencode-go` → `OC`); providers without a Burn counterpart have no marker. Stable CLI aliases keep the row compact: Claude is `CC`, Claude 2 is `CC2`, OpenCode is `OC`, and Codex is `CX`. Each provider shows its most-used active limit; dollar spend is omitted. Providers without an active numeric limit, and missing or malformed snapshots, are quietly omitted. The snapshot is read at startup and once per minute without triggering a paid refresh. |
| `↑ 412k ↓ 18k` | Tokens spent in this Pi session: input including cache reads and writes, then output. Every usage icon is separated from its value for legibility. |
| `↺ 71%` | Share of input served from cache. Green over 50%. A collapse after a model switch is expected because caches are provider-specific. |
| `$ 1.87` | Session cost, two decimals. |
| `◫ 34%/1.0M 660k left` | Context used against the window and the remaining capacity. Green over 50% remaining, amber under, red under 20%. |

## Narrow terminals

The usage block owns the right edge. When both sides do not fit, left-side optional state truncates before the right-side usage figures. The footer never wraps.

## Hiding it

```
/zen
```

Toggles the whole line away and back. Nothing stops being tracked while it is hidden; `/stats` and `/dash` still have everything.

## Changing it

Everything is computed in one `render(width)` function. Token totals come from `ctx.sessionManager.getBranch()`, context from `ctx.getContextUsage()`, all-provider account usage from the cached output of `burn --json`, connected MCP names from `pi-mcp-adapter/status/v1`, and extension statuses from the `FooterDataProvider`. `ctx.ui.setFooter(undefined)` restores Pi's built-in footer.
