---
title: Requirements
sidebar_position: 2
---

# Requirements

Every request made of this project, and what happened to it. Append-only: entries change status, they are never deleted.

This exists so that “did we do everything?” has an answer that is looked up rather than remembered. Requirements arrive scattered through conversations; without a ledger, the only record is a transcript nobody will re-read.

Rows 1–39 are a backfill from the 2026-08-10 changelog. Later rows were recorded when they arrived.

**Status meanings**

| Status | Means |
| --- | --- |
| `done` | Built **and verified**. The verification is named. |
| `partial` | Some of it works. What is missing is stated. |
| `open` | Accepted, not started. |
| `blocked` | Cannot proceed. The blocker is named, and whose it is. |
| `declined` | Deliberately not doing it. The reason is recorded. |
| `withdrawn` | The requester dropped it. |

`done` requires evidence. “Written” is not `done`. If it loaded but was never exercised, it is `partial`.

## Open and partial

| # | Requirement | Status | What remains |
| --- | --- | --- | --- |
| 11 | The statusline presents the configured operational state | partial | Current idle, held and working layouts are visually verified; narrow-terminal behavior and non-zero cache formatting still need live inspection. |
| 13 | `/stats` reports model, tool and compaction usage; the former subagent clause is superseded by #92 | partial | Extension loads and the zero-activity output was captured after removal; non-zero per-model/tool and compacted output still needs current live exercise. |
| 130 | `/done` snapshots pre-report session usage and elapsed time to `~/reports/`, then gracefully closes Pi | superseded | The implementation had drifted ahead of this open requirement with shutdown deliberately disabled; the receipt workflow is removed by #132. |
| 131 | Remove the session replay command, recorder, browser launcher, stored event logs, documentation, and installed extension from the root Pi configuration | done | Source and installed extension, feature page, and event-log directory are absent; docs build passes; free e2e passes 17/17; fresh tmux `/ani` autocomplete contains no replay command or status. |
| 132 | Remove the session completion report command, report generation, output directory, documentation, and installed behavior from the root Pi configuration | done | Command registration, report code, page, sidebar entry, and empty output directory are absent; docs build passes; free e2e passes 17/17; fresh tmux `/don` autocomplete contains no `/done`. |
| 133 | Keep only `code-review`, `diagnosing-bugs`, `codebase-design`, `find-skills`, `git-guardrails-claude-code`, and `grill-me` under user-global skill discovery | done | The global directory and lockfile contain exactly those six; retained workflows no longer invoke removed skills; fresh Pi exposes exactly 13 total skill commands including configuration and package skills; tmux autocomplete contains no removed skill; docs build and free e2e 17/17 pass. |
| 14 | `!` and `!!` shell commands are logged per session with hidden entries marked | partial | Extension loads; no current end-to-end interaction evidence was recovered. |
| 15 | `/gc` reports and prunes old sessions | partial | Extension loads; destructive prune path has not been exercised during this takeover. |
| 17 | Lazy MCP servers load and Linear writes remain gated | partial | Config parses; individual lazy connections and the write gate were not exercised during this takeover. |
| 27 | Remote session discovery and RPC-over-SSH handoff | open | Roadmap only; Pi has no daemon/socket discovery, so an explicit host list is still required. |
| 29 | `/draft` saves global Markdown drafts and offers edit/send actions | superseded | Removed from the root configuration by #124. |
| 30 | `/limit` blocks new turns at a money or token cap without destroying the session | partial | Parser and recovery tests pass; pane `%142` exercised a live hard token cap and retained prompt, while the dollar-cap path remains headless-only. |
| 31 | `/kill` stops immediately or on a schedule | partial | Time-parser tests pass and extension loads; shutdown behavior has not been exercised. |
| 36 | Notifications fire only when Pi needs attention and its pane is not visible | partial | Four focus-detector tests and a real `/notify test` toast pass; an automatic attention/settled trigger while hidden remains unverified. |
| 37 | Statusline order, compact formatting and narrow-terminal dropping follow importance | partial | Wide idle/held/working layouts pass pane inspection; narrow-terminal dropping remains unverified. |
| 50 | Add tools for web scraping | open | Future feature; scope, sites, extraction needs and safety constraints are not decided yet. |

## Delivered

| # | Requirement | Status | Verified by |
| --- | --- | --- | --- |
| 1 | Treat documentation as the specification and code divergence as a defect | done | `APPEND_SYSTEM.md` is linked by `link.sh`; inherited `./tests/e2e.sh` passed 15/15 on 2026-08-10. |
| 2 | Link tracked Pi configuration into `~/.pi/agent` idempotently | done | Inherited e2e: 31 links, no dangling links, all targets in the repository. |
| 3 | Configure scoped model cycling and model defaults | done | `settings.json` parses in e2e and scoped models are present in the shipped configuration. |
| 4 | Register `claude` and `claude2` as selectable primary providers | done | Inherited e2e found both registrations and both CLIs on `PATH`. |
| 6 | Provide `all`, `ask` and `read-only` permission modes with runtime path grants | done | 25 read-only classifier assertions pass; permission extensions load in e2e. |
| 8 | Support compact, fork, tree, clone, switch, name and session interruption controls | done | Built-in Pi behavior was exercised during initial configuration and the current config/keybindings parse in e2e. |
| 9 | `/notes` records text without sending it to a model | superseded | Historical delivery retained; removed from the root configuration by #124. |
| 10 | Apply the documented key overrides and cap autocomplete at 10 rows | done | Config parses in e2e; pane `%115` showed exactly 10 of 92 slash-command matches. |
| 16 | Install only general global skills; keep project-specific skills local | done | `link.sh` target audit passes in current e2e. |
| 18 | Run Claude subagents in bounded persistent slot pools | done | Both Claude CLIs are present; slot helper and prompt-filter assertions pass. |
| 20 | Test pure shipped logic and real extension/config loading | done | `tests/unit.test.ts` passes 51 assertions; inherited e2e passes 15/15. |
| 21 | Idle prompts wait in a five-second FIFO send-hold queue | done | 14 queue/lifecycle tests pass; fresh tmux pane showed FIFO `+1`, latest-only `/abort`, and clean `/reload`. |
| 28 | Send-hold renders a countdown and queue preview above the editor | done | Captured fresh pane `%44`: 30-second test hold, preview, `…and 1 more`, and `hold 30s +1 /abort`. |
| 40 | Add and maintain this append-only requirements ledger | done | Docusaurus production build passes; final repository e2e passes 16/16. |
| 44 | Visually verify the current statusline layout | done | Fresh panes `%43`/`%44` captured idle, held and working layouts after loading the current build. |
| 49 | Review Claude’s send-hold implementation against Pi’s extension API and fix verified defects | done | Installed Pi docs/API reviewed; 14 regression tests, docs build, e2e 16/16, and live tmux hold/reload captures pass. |
| 42 | Prove a `<<<<` forward is consumed by a live receiving TUI session | superseded | Historical verification retained; forwarding was removed by #124. |
| 12 | `/dash` shows the complete agent capability dashboard | done | Real RPC command probe passes; fresh tmux overlay captured model, models, cwd, MCP, tools, disk and spend sections after fixing API drift and tool-column spacing. |
| 45 | Visually verify the `/dash` overlay | done | Fresh pane captures covered the first page and scrolled lower sections; tool names have readable gaps. |
| 46 | Visually verify `/drive` selection dialogs | done | Fresh pane captured all five routing categories and the `drive → waiting` statusline segment. |
| 47 | Visually verify the `/draft` picker | superseded | Historical verification retained; drafts were removed by #124. |
| 48 | Fire and observe a real notification toast | done | `/notify test` reported hidden detection and dunst history recorded app `pi`, summary `pi · test`, body `Notifications are working`, id 519. |
| 22 | Count compactions in session statistics | done | Delivered behavior recorded in the 2026-08-10 changelog; extension loads in e2e. |
| 23 | Keep project-only component extraction rules out of global configuration | done | Link audit confirms only tracked global skills are installed. |
| 24 | Persist forwarded messages without loss using a configurable, blank-by-default wrapper | superseded | Historical delivery retained; forwarding was removed by #124. |
| 26 | `/zen` hides the statusline | done | Delivered behavior recorded in the 2026-08-10 changelog; extension loads in e2e. |
| 32 | `/docs` serves the local Docusaurus site and supports loose page matching and stop | done | Four real-socket server-detection tests cover IPv4, IPv6, free and held ports; extension loads in e2e. |
| 33 | `/demo` proves features in an appropriate real medium | done | Skill is installed by the passing link audit; medium-selection behavior is specified and was delivered in the 2026-08-10 demo work. |
| 34 | Remove parent-only tools and Pi documentation pointers from Claude subagent prompts | done | Four prompt-filter assertions pass. |
| 35 | Detect live docs servers over HTTP across IPv4 and IPv6 | done | Four `lib/local-server.ts` assertions use real sockets and servers. |
| 38 | Ship the reusable `source-of-truth` skill and requirements-ledger template | done | Skill and asset exist through the passing link audit; this page was bootstrapped from the shipped asset. |
| 39 | Let demos choose browser, tmux, curl, database CLI or diff and preserve non-obvious setup | done | Delivered behavior recorded in the 2026-08-10 changelog and installed skill. |
| 54 | Show remaining Claude subscription quota proactively | done | A live collection refreshed both account caches through isolated `/usage` probes and returned current windows; direct JSON inspection and the paid repository e2e suite passed. |
| 56 | Render the snapshot in a minimal Tailwind CDN and Alpine.js dashboard that recollects on refresh | done | Same-origin refresh returned four healthy agents; foreign Host and cross-origin requests returned 403; a real Chrome capture verified the two-column cards, progress bars, warning state and raw-JSON section. |
| 57 | Provide a `spend` command that prints the generated usage JSON, and serves the dashboard with `--serve` | done | `command -v` resolves the tracked symlink; a missing temporary snapshot was collected with four healthy agents and mode `0600`; the default command wrote the snapshot to stdout, and `--serve` bound loopback and answered `/` and `/usage.json` with 200. |
| 58 | Scrub sensitive agent-usage details through CLI options, with scrubbing enabled by default | done | Default and strict snapshots contained no email patterns; strict removed granular keys; `--no-scrub` retained identity only explicitly; legacy/full files were sanitized before opening or serving; default commands preserved stricter existing files; strict dashboard refresh returned four healthy agents and Chrome showed no identities. |
| 59 | Syntax-highlight rendered code blocks, including Bash tool calls with embedded-language heredocs | done | Five inference/parser regressions pass; e2e 16/16; pane `%88` showed Bash, Python heredoc and inferred Markdown fence tokens in distinct Rose Pine syntax colours. |
| 25 | `/todo` maintains several session-scoped plans and renders progress | done | Current-session tool calls created and updated separate lists; filesystem inspection found one title-derived JSON file per list under the session directory. |
| 41 | Stop `/` autocomplete from shifting the layout | done | `autocompleteMaxVisible` is 10; narrow pane `%115` showed exactly 10 visible matches and paged count `(1/92)`. |
| 43 | Store one title-derived JSON file per `/todo` list | done | The delegated scalable choice matches the implementation; current session contains separate files for each concurrently active plan. |
| 60 | Keep questions awaiting the user's answer visible when the transcript scrolls | done | Three lifecycle assertions and e2e pass; pane `%115` restored two questions above the editor and an ordinary held answer cleared them while commands remained available. |
| 61 | Rename the held-queue release command to `/send`; the former Ctrl+Enter alias is superseded by #103 | superseded | #126 removes `/send` in favor of EX `:w!`. |
| 64 | Copy a rendered code snippet with a one-step interaction | done | Three selection regressions and e2e pass; pane `%115` showed the shortcut hint, `/copy-code` and live `Ctrl+Alt+C` both replaced the X11 clipboard with the exact mixed-language command. |
| 65 | Use the upstream Matt Pocock installation as the sole canonical `grill-me` skill | done | `.agents/.skill-lock.json` identifies `mattpocock/skills`; the repo copy/link were removed, e2e link audit passed, and pane `%115` started without a skill-collision warning. |
| 66 | Keep and display per-step session token cost and elapsed time history | done | Three projection/timing regressions and e2e 16/16 pass; pane `%118` showed exact and estimated model/tool durations, token categories, per-step cost and cumulative spend in the `/costs` overlay. |
| 62 | Add `/pause` with duration presets and a custom-duration choice | done | Pause/queue regressions and e2e 16/16 pass; pane `%142` showed the preset picker, paused FIFO widget/status, `/pause off`, and the deadline restored after `/reload`. |
| 63 | At a hard token cap, offer pause-and-retry, switch-model-with-handoff, or cancel | done | Five guardrail recovery assertions plus send-hold cancellation pass; pane `%142` showed the live three-choice menu and alternate-model picker, while the switch regression proves allowance reset and injection of the upstream handoff workflow with the retained prompt. |
| 67 | Move the agent-usage code out of the kickstart repository into `~/dev/spend` | done | `command -v spend` resolves through `~/.local/bin/spend` to `/home/alex/dev/spend/spend` and printed a live snapshot; `stage-03.sh`, `install.md` and the agent-usage page point at the new path. |
| 68 | Make `spend` print the snapshot JSON instead of opening an editor | done | Piped output is byte-identical to the snapshot and TTY output goes through `jq`; `--refresh` recollected four healthy agents in 4.5s; the mutually-exclusive and unknown-option paths still exit 2. |
| 69 | Install the dashboard as a systemd user service | done | `install.sh` writes, enables and restarts `spend.service`; under systemd a `POST /api/refresh` returned all four agents `ok`, proving the explicit unit `PATH` reaches the agent CLIs; `--uninstall` left no unit and no symlink, and reinstalling returned the service to `active`. |
| 70 | Serve the dashboard on port 8888 | done | Unit `ExecStart` carries `--port 8888` and `http://127.0.0.1:8888/` answered 200; `--port` on `install.sh` and `spend` was exercised on 7777/4313. |
| 71 | Recollect the dashboard snapshot every minute | done | With the tab left idle, the service logged `POST /api/refresh` 60s after page load; the header countdown reports the next collection and the checkbox state persists in `localStorage`. |
| 72 | Present one provider per row, sorted alphabetically, without raw JSON or collection detail | done | A 1440px Chrome capture shows Agent/Limits/Spend/Usage rows in the order Claude, Claude 2, Codex, OpenCode, with the raw-JSON panel, source-method line and warning text removed. |
| 73 | Let `spend --serve` cooperate with an already-running dashboard | done | Against a live dashboard it reported the running URL and opened it instead of binding; against a foreign listener on 4399 it refused with exit 1. |
| 74 | Document how each provider's spend and usage is actually obtained, and whether an official API could replace it | done | `docs/collection.md` covers the tmux `/usage` probe and state cache, the Codex app-server JSON-RPC methods, and the OpenCode local database, field by field; `docs/apis.md` records that the published Anthropic and OpenAI usage APIs meter API-key billing rather than subscription windows, that Codex's local JSON-RPC is the one genuine API of the four, and that OpenCode Go's balance stays `null` by choice. |
| 75 | Rename the tool from `spend` to `burn` and publish it | done | Tool, binary, module, unit, port env and cache path renamed (`~/dev/burn`, `burn`, `burn.py`, `burn.service`, `BURN_PORT`, `~/.cache/burn`) while the JSON contract's own `spend` fields are untouched; the reinstalled unit collected four `ok` agents over `/api/refresh` and the CLI printed the snapshot; pushed to github.com/alexeightsix/burn. |
| 76 | Render the snapshot in a terminal UI with `--full-screen` and `--auto` | done | Textual app in `tui.py`, inline by default; a headless `run_test` at 112×30 rendered all agent rows with per-limit bars, `a` toggled auto-refresh, `r` ran one threaded collection, and `q` exited. `collect` and `serve` still run with Textual absent. |
| 77 | Make the interface previewable and installable in one command | done | `docker build -q` + `docker run -p 8899:8888` served the demo snapshot (200 on `/`, three agents in `/usage.json`), refresh returned 503 in `--no-collect` mode, and a foreign `Host` still returned 403; the loopback service returned 200 and 403 respectively after the same host-check change. `bootstrap.sh` passes `sh -n`, but end-to-end `curl \| sh` cannot run until the repository is public. |
| 78 | Give the repository an SEO-oriented description and topics, and stop documenting the second Claude account | done | `gh repo view` returns the new description and 16 topics; no `Claude 2` string remains in the README or docs, while the `CLAUDE_CONFIG_DIR` mechanism stays implemented and is described once in `docs/collection.md`. |
| 79 | Review and improve the tracked Pi configuration against its docs and installed Pi 0.84.1 APIs | done | Corrected both command-time `setModel` call sites and the response-event payload against installed 0.84.1 types/source; automatic discovery produced 32 idempotent links; 88 unit assertions and e2e 16/16 passed; a 120-column tmux pane showed `/drive` enabled with one `drive → waiting` status segment and no extension error. |
| 80 | When drive is enabled, classify and route requests automatically without asking; show classification dialogs only after explicit `/drive manual` opt-in | done | 10 classifier/mode assertions, full 98-assertion suite, e2e 16/16, pane `%287` automatic no-dialog route, and pane `%288` explicit manual picker |
| 81 | Add read-only LSP tools backed at minimum by `gopls` and TypeScript's native Go server (`tsgo`) | done | 7 protocol/routing/format assertions, direct live hover/definition/symbol/diagnostic queries against both servers, and e2e 18/18 including extension load and binary probes. |
| 82 | Add the useful gaps from oh-my-pi's broad built-in tool inventory to the roadmap | done | Roadmap audit records candidate capabilities, delivery order, prompt-cost constraints and permission boundaries; later implementations require separate scoped requirements. |
| 85 | Do not enforce the send-hold countdown on the first prompt in a new session | done | Regression reproduces and fixes the one-shot bypass while preserving later holds; 106-unit/e2e 18/18 pass; fresh pane `%303` sent prompt one immediately and rendered prompt two at `hold 30s`. |
| 86 | Preserve language syntax colours in rendered edit diffs | done | The gutter/source, legacy-path and elision regressions pass in the full 109-assertion suite; e2e passes 18/18; pane `%435` rendered one Go addition with foam gutter, pine keyword, rose function and gold string ANSI colours. |
| 87 | Do not repeat todo progress in the statusline while the todo widget is visible above the editor | done | E2e passes 18/18; pane `%435` contained the active todo widget once and zero `todo n/n` statusline segments. |
| 88 | Remove `/drive` so prompts use the explicitly selected model and thinking level | done | Dedicated docs, extension, classifier, tests, installed link, and active references are absent; 99 unit assertions and e2e 18/18 pass, the docs production build passes, and a fresh tmux pane's `/dr` autocomplete showed `/draft` with no `/drive`. |
| 91 | Confirm before acting on a request that plausibly belongs to a different project | done | In fresh pane `%654`, after establishing a Python disk-usage CLI brief, a React `Navbar.tsx` request pinned an unrelated-project confirmation without using a tool. |
| 92 | Remove every active Claude- or Anthropic-specific feature from the tracked Pi configuration | done | The custom provider/subagent files and installed links are absent; `settings.json` has seven non-Claude scoped models; 94 unit assertions and e2e 17/17 pass; `pi --list-models claude` contains no `claude-code` provider; fresh tmux captures show the provider-generic statusline and stats plus seven Claude-free `/dash` models. Pi's upstream built-in catalogue is unchanged. |
| 93 | Make bare `/docs` open the changelog at `http://localhost:3565/changelog` | done | Fresh tmux invocations of both the global `/docs` and Pistafit project `/docs:1` reported the exact URL; its response was inspected and contained the changelog page. The source-of-truth skill asset carries the same default for future projects. |
| 94 | Show only `LSP ✓` at the far-right edge of the global status line when the LSP extension loads | done | The placement regression passes, the free e2e suite passes 17/17 including real extension loading, and fresh pane `%23` shows `LSP ✓` as the final segment. |
| 95 | Track recent skills in session state; footer display is superseded by #102 | done | Skill recognition, recency/deduplication and restoration remain tested; #102 moves presentation to `/dash`. |
| 96 | Add a root-config TLDR skill that summarizes the session and reuses a cached result when nothing meaningful changed | done | Six TLDR regressions and the full 104-test suite pass; `link.sh` installs 32 idempotent links; free e2e passes 17/17; pane `%75` rendered `refreshed`, then `cached · unchanged`, and retained the cache through `/reload`; the Docusaurus build passes. |
| 89 | Prefer native bounded Pi tools, then modern global CLI primitives for shell work | done | The coding-first prompt and tool metadata establish the precedence; `rg`, `fd`, `jq`, `yq`, `delta`, `ast-grep`, `gopls`, and `tsgo` resolved and were exercised during the audit; final e2e passes 17/17. |
| 97 | Remove only the Pi configuration bloat the user approves after seeing an audit | done | After explicit `lean` approval, link reconciliation removed plan mode and both wrappers; `pi-updater`, the 207 MB skill toggle, and duplicate third-party skill links are absent; 30 tracked links are idempotent and e2e passes 17/17. |
| 98 | Keep a precise coding toolset with semantic LSP navigation | done | Native file/search tools remain available, the LSP extension returns clean diagnostics for the new subagent extension, both server binaries run, and e2e passes 17/17. |
| 99 | Add provider-generic subagents for bounded, isolated coding work | done | Five pure regressions pass; a real low-thinking parent invoked one read-only child with the selected OpenAI Codex model and returned `# Pi — default instance`; delegated usage is attached to the tool result. |
| 100 | Make the global prompt concise and coding-first unless the user specifies otherwise | done | E2e asserts the coding-first policy and absence of the questionnaire; fresh pane `%2` accepted the initial coding-context prompt immediately and replied `ok`. |
| 101 | Replace permission, cache, and context labels in the statusline with compact icons | done | The compact-icon regression passes; fresh pane `%2` shows gold `●`, `↺0%`, and `◫2%/272k 266k left` aligned in the live footer. |
| 102 | Remove skill history from the statusline and show it on demand in `/dash`, capped at two plus `+N more` | done | Recency/projection regressions pass; pane `%3` has no footer skills and `/dash` renders the dedicated recent-skills section. |
| 103 | Make Enter insert a newline and Ctrl+Enter submit | done | `keybindings.json` owns both actions; pane `%3` retained `first-line` and `second-line` in the editor after Enter, then the Kitty Ctrl+Enter sequence submitted them as one multiline prompt. |
| 104 | Explain thinking-border and permission state in the footer itself | done | Regressions cover `●!`/`●?`/`●–` and `◇level`; pane `%3` shows gold `●?`, then Shift+Tab changed the border and footer from `◇low` to `◇medium`. |
| 105 | Use compact stable aliases for every configured model in the statusline | done | Regression covers all seven configured ids plus fallback; pane `%3` shows `5.6-sol`. |

## Latest additions

| # | Requirement | Status | What remains |
| --- | --- | --- | --- |
| 106 | `/btw <task>` forks the current session into a writable background Pi in a new right-hand tmux pane named `Copy of <current session>` and immediately returns control to the original pane | done | Originally delivered and verified as `/background`; renamed to `/btw` by #110. |
| 107 | `/fork` keeps its branch-point picker but opens the selected fork in a new right-hand tmux pane named `Copy of <current session>` instead of replacing the current pane | done | The built-in picker selected message 7 in `%6`; the cancellable pre-fork hook opened `%8` on the right, restored the selected MCP prompt into its editor, and retained focus in original pane `%5`; free e2e passes. |
| 108 | Put input/output tokens, cache hit rate, session cost, and context usage together at the right edge of the statusline | done | Focused regressions and free e2e 17/17 pass; panes `%6` and `%9` show `↑… ↓… ↺… $… ◫… left` aligned together at the right edge at two pane widths. |
| 109 | Replace `MCP 0/5` with up to three connected MCP server names followed by `+N others`; show nothing before a server connects | done | Projection regression covers empty, duplicate, under-limit and `+2 others` states; pane `%6` showed no MCP segment before connection, then `%9` ran `/mcp reconnect linear` and showed `linear` exactly once; free e2e passes. |
| 110 | Rename the background-copy slash command to `/btw` | done | `/btw` is registered and exercised; `/background` is absent from the implementation and command inventory; #111 records its final non-forking behavior. |
| 111 | `/btw` launches a non-forking writable side quest after asking for parent/none/other session context and a configured model; `/fork` remains the real session fork | done | Pane `%15` showed the three context choices and all seven configured models, launched the selected Codex model without another pane, and reported completion back to the parent; an E2BIG failure on unbounded parent context was fixed with an 80 KB recent-context boundary; free e2e passes 17/17. |
| 112 | Bare interactive `pi` asks Resume or New session with Resume selected by default; explicit CLI intent bypasses the chooser | superseded | Historical delivery retained; the startup chooser is removed by #134. |
| 113 | `/animate` records the current Pi session as typed events and opens a live, scrub-capable GSAP replay with chat, edits, tools, output, and sticky todos | superseded | Historical delivery retained; the replay feature is removed by #131. |
| 114 | Show every healthy provider's most-used active allowance in the statusline from the cached `burn --json` snapshot, ordered from most to least used with compact CLI aliases and without command labels or dollar spend | done | Projection regressions cover aliases, descending usage, highest active limits, malformed data, and unhealthy agents; free e2e passes 17/17; fresh pane `%49` shows `OC 100%  CX 76%  CC 21%  CC2 21%`. |
| 115 | Make the pi-vim wrapper global: only EX `:w`/`:W` submits, EX `:q` quits, and the compact colored mode label renders above the prompt border in every working directory | superseded | Submission and quit behavior remain; #125 supersedes the text mode label with cursor shape. |
| 122 | Remove the separate editor mode row and show Vim mode as the far-left statusline segment, before all existing statuses | superseded | #125 removes the text segment and uses cursor shape instead. |
| 123 | Preserve terminal bracketed paste, system-clipboard paste, Vim yank-to-clipboard, and Vim put while the global prompt wrapper is active | done | `tests/vim-clipboard.e2e.sh` reproduced the dead Ctrl+V path, then passed all four real tmux/X11 paths after the wrapper forwarded pi-vim's app handlers: exact bracketed-paste submission, Ctrl+V insertion, exact yank mirroring, and exact clipboard put submission. |
| 124 | Remove `/draft`, cross-session forwarding, and `/notes` from the root Pi configuration | done | Active docs, extensions, shared forwarding code, tests, and installed links are absent; free e2e passes. |
| 125 | Use a bar cursor for Vim Insert mode and a block cursor for Normal, Visual, V-LINE, and EX; show no text mode indicator | done | The wrapper propagates editor focus so pi-vim can position and shape the hardware cursor; focused tmux inspection and free e2e pass. |
| 126 | Make EX `:w!` submit its prompt and immediately flush every held message; remove `/send` | done | Send-hold regression covers the event-driven FIFO release, `/send` is absent from the command registration, and free e2e passes. |
| 116 | Make agent-run Git commands non-interactive and prevent hook bypass with `--no-verify` | done | Shipping-command classifier regressions pass; the active interceptor blocked a real `--no-verify` tool call; free e2e loads the installed extension. |
| 117 | Add `/toggle-skills` to search discovered skills and switch each between agent-invocable and manual-only | done | On-disk regressions drive the real locator, inventory, planner and atomic writer over a temporary skill tree in both directions, including permission preservation and the stale-file guard; command regressions cover reload-on-apply and the four paths that must not reload. Session `toggletest` toggled a real project skill to manual-only and back, each time writing the file and printing `Reloaded keybindings, extensions, skills, prompts, themes, and context files`. This deliberately revises #97's removal of the earlier heavyweight implementation. |
| 118 | Resume the unfinished task automatically after every successful compaction | partial | Continuation-prompt and delivery regressions pass: the extension registers for `session_compact` and `session_shutdown`, defers exactly one follow-up per compaction, and cancels a pending one at shutdown; free e2e loads the extension. A real successful compaction still has not exercised delivery — on 2026-08-12 every configured provider refused a turn (OpenRouter unauthenticated, OpenCode out of balance, Codex at its usage limit, Anthropic requiring extra usage), so the live check needs a funded provider. |
| 119 | Put visual separation between each statusline usage icon and its numeric value | done | Formatting regressions and free e2e 17/17 pass; pane `%54` shows `↑ 0 ↓ 0  $ 0.00  ◫ 0%/272k` with visible icon/value gaps. |
| 120 | In pi-vim Insert mode, plain Return inserts a newline without submitting the prompt | done | Pane `%55` retained `first-line` and `second-line` as two editor rows without sending; free e2e passes 17/17. |
| 121 | Mark the Burn allowance related to the active Pi model with `*` | done | Provider mapping regression and free e2e 17/17 pass; pane `%56` shows `CX* 76%` for active `openai-codex/gpt-5.6-sol`. |
| 127 | Collect unit tests that live beside extension code, and keep that code loadable by the type-stripping test runner | done | `e2e.sh` now collects `tests/*.test.ts` plus every `extensions/**/*.test.ts`; the four previously uncollected skill-toggle files run, and the constructor parameter properties that made them unloadable are gone. Free e2e reports 134 assertions and still passes 17/17. |
| 128 | Add a root-level `auto-push` skill that creates its worker when absent, does nothing without a running tmux server, starts the `automations` session, and accepts a target directory | done | Isolated shell integration exercises no-tmux and live-worker paths; docs build and free e2e pass 17/17; `link.sh` installs the skill. |
| 129 | Start auto-push for `/home/alex/dev/vm` after its Gitea repository and remote exist | done | Gitea shows `alex/vm` on `main` at sync commit `9290cf0`; tmux window `automations:@564` is running the worker and its pane captured the successful first push. |
| 134 | Remove the root-level Resume/New fzf chooser so bare `pi` starts a new session directly | done | A pseudo-TTY regression fails if bare `pi` does not dispatch the real binary with zero arguments; the docs build passes; free e2e passes 18/18; a fresh tmux pane opened the normal Pi editor directly with no startup chooser. |

## Blocked, declined and withdrawn

| # | Requirement | Status | Reason |
| --- | --- | --- | --- |
| 5 | `/drive` classifies requests and selects an available model and effort level | withdrawn | The user removed automatic routing in favour of explicit model and thinking-level selection. |
| 7 | Plan mode constrains tools and records a reviewable plan | withdrawn | The approved lean cut uses read-only permission mode for safe analysis and structured todos for plans instead of maintaining a second planning state. |
| 19 | `/improve` launches a fresh scoped self-review | withdrawn | The user replaced the separate-agent workflow with an in-session improvement workflow, then removed the redundant command wrapper under #97. |
| 83 | Make `/improve` establish a concrete user direction before investigating or editing | withdrawn | Superseded by the coding-first prompt: ordinary improvement requests act when scoped and ask only when genuinely blocked. |
| 84 | Keep `/improve` in the current agent session instead of spawning another Pi process | withdrawn | The wrapper was removed; ordinary improvement requests already stay in the current session. |
| 90 | Ask for the project's nature and purpose before working in every new interactive conversation | withdrawn | The mandatory questionnaire added friction even when the first prompt supplied context; #100 replaces it with targeted clarification and wrong-project checks. |
| 51 | Use `opencode-go/kimi-k3` successfully | blocked | External provider/workspace failure reported by the user; explicitly not configuration code to fix. |
| 52 | Use `openrouter/nvidia/nemotron-3-ultra-550b-a55b:free` | blocked | `OPENROUTER_API_KEY` is a placeholder pending rotation; external credential issue. |
| 53 | Use `openrouter/openai/gpt-oss-20b:free` | blocked | `OPENROUTER_API_KEY` is a placeholder pending rotation; external credential issue. |
| 55 | Produce one JSON snapshot of spend, remaining limits, account state and useful usage for Claude, Claude2, OpenCode and Codex | withdrawn | Superseded by #92 for this Pi configuration. The external `burn` repository is outside this tracked directory and was intentionally left unchanged. |

## Keeping it honest

- Add the row **when the request arrives**, not when it is finished. A requirement that only appears once satisfied is a requirement that can be quietly forgotten.
- Record requests you decline and why. A decision with no record gets re-litigated.
- Split a request that has parts. One row per thing that can independently succeed or fail, or the status is a lie about half of it.
- Re-read this before answering “is it all done”. That is the entire point of the file.
