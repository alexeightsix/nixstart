---
title: Changelog
sidebar_position: 99
---

# Changelog

Every edit to this documentation gets an entry here. The docs are the source of truth for the configuration, so a change to them is a change to the specification — it needs a record, in the same way a code change needs a commit message.

**Rule:** never edit a page without logging it here, and always state **why**. What changed is recoverable from git; why it changed is not.

**Format:** newest first, dated. Each dated block opens with the reason for the change, then one bullet per page saying what the behaviour now is — not what was typed.

## 2026-08-18 — SuperGrok should be a scoped model

**Why:** billed `api.x.ai` keys need team credits the account does not have; SuperGrok is already the subscription the user can use, and `pi-grok` is how Pi rides that quota. The OpenCode and OpenRouter models with the context-window bars should leave the `Ctrl+P` cycle; Codex stays.

- **models** — the cycle is the three Codex models plus `xai-oauth/grok-4.6` and `xai-oauth/grok-build`. Login is `/login` → xAI (SuperGrok Subscription). `kimi-k3`, `deepseek-v4-flash`, and the two OpenRouter free models are no longer scoped.
- **install** — the root package list includes pinned `git:github.com/stnly/pi-grok@v0.10.1`.

## 2026-08-15 — bare Pi startup should stay direct

**Why:** the root-level Resume/New fzf prompt adds a second session picker before Pi even starts; session recovery should remain explicit through `pi --resume` or the in-session picker.

- **sessions** — bare `pi` starts a new session directly, while `pi --resume` remains the explicit way to choose existing work at startup.
- **install** — the launcher remains only to dispatch to the real Pi executable with its compatible bundled Node runtime; it no longer owns startup UI.
- **requirements** — the former startup-chooser requirement is superseded and its complete removal is tracked independently.

## 2026-08-14 — the user-global skill set should stay deliberate

**Why:** globally discovered skills spend permanent attention or human recall and had grown into overlapping workflows with dependencies on other installed skills; retaining only the six workflows the user named keeps discovery predictable without weakening those retained workflows.

- **skills** — user-global discovery contains only `code-review`, `diagnosing-bugs`, `codebase-design`, `find-skills`, `git-guardrails-claude-code`, and a self-contained `grill-me`; configuration-owned and package-provided skills are unchanged.
- **intro** — the configuration inventory names the exact user-global allowlist instead of describing an unrestricted third-party collection.
- **guardrails** — model switching at a hard token limit uses its built-in redacted handoff recipe rather than depending on a removed global skill.
- **requirements** — pruning the global directories, lock metadata, dependencies, and live skill command inventory is tracked as one removal requirement.

## 2026-08-14 — session completion does not need a receipt command

**Why:** transcripts already preserve completed work, and maintaining another command, report format, output directory, and shutdown path adds a second completion workflow the user no longer wants.

- **done** — the dedicated page is removed; Pi no longer writes a completion report or exposes a report-and-shutdown command.
- **requirements** — the unfinished receipt requirement is superseded and complete removal is tracked independently.

## 2026-08-14 — session replay is not part of the editor

**Why:** recording every Pi event and coupling the root configuration to a separate browser application adds sensitive local state and maintenance for a workflow the user no longer wants.

- **animate** — the dedicated command page is removed; the root configuration no longer records sessions for browser replay or launches the replay application.
- **requirements** — the earlier replay requirement is superseded and complete removal is tracked independently.

## 2026-08-13 — finishing a session needs a receipt

**Why:** closing Pi currently preserves the transcript but leaves no concise, discoverable record of elapsed time and provider-reported usage; producing that record through a model would also charge tokens that cannot belong to its own snapshot.

- **done** — new page. `/done` deterministically snapshots the active branch to a timestamped Markdown report under `~/reports/`, reports the path, and gracefully shuts down; write failure leaves the session open.
- **requirements** — pre-report accounting, durable report creation, and graceful shutdown are tracked as one atomic completion flow.

## 2026-08-13 — continuous repository sync must be explicit and isolated

**Why:** the user wants repository changes committed and pushed every second without occupying the working Pi session, while preserving the existing tmux server as the boundary that decides whether background automation may start. Live inspection then exposed that muxbar adds a sidebar pane and makes it active, so capturing the window default showed the dashboard rather than the worker even while the worker was healthy.

- **skills** — `/skill:auto-push <target-directory>` is manual-only, creates its persistent worker when absent, exits without side effects when tmux is not running, and runs each target in the detached `automations` session; the launcher reports the exact worker pane so verification remains correct when muxbar changes the active pane.
- **intro** — the tracked skill inventory includes every configuration-owned skill; the previous three-skill list had drifted behind the already documented `tldr` and `wrong-number` additions.
- **requirements** — continuous Git sync and starting it for the vm repository are tracked independently because the reusable capability can succeed while remote repository setup remains blocked.

## 2026-08-12 — adopted features had to be exercised, not just loaded

**Why:** `/toggle-skills` and post-compaction continuation were both recorded as `partial` because nothing had ever applied a real change or delivered a real continuation. Reviewing them turned up the reason the gap persisted: four of the skill-toggle test files were never collected by any test command, and the extension used constructor parameter properties that the type-stripping runner cannot load, so its suite failed the moment it was collected. Pi transpiles extensions through jiti and accepts that syntax, which is exactly why the restriction had to be written down — the failure only appears in the test run.

- **testing** — the unit command collects `tests/*.test.ts` **and** every `extensions/**/*.test.ts`, and extension code avoids TypeScript syntax with no JavaScript form so the stripping runner can load it.
- **skills** — `/toggle-skills` is verified end to end: the real locator, inventory, planner and atomic writer round-trip a skill file on disk in both directions, preserving permissions, leaving no temporary files, and refusing to clobber a file edited while the overlay was open. Applying reloads pi; cancelling, an empty plan, a non-interactive session and a failed scan all leave the session loaded as it was.
- **requirements** — #117 is `done`; #118 remains `partial` and now names what is missing and why the live check could not run.

## 2026-08-12 — misaddressed requests need a clean handoff

**Why:** a request typed in the wrong agent conversation should be recoverable without manually reconstructing the relevant context or copying a prompt out of the transcript.

- **skills** — `/skill:wrong-number` turns the preceding user request and only its necessary conversational context into a self-contained prompt on the system clipboard.

## 2026-08-12 — cursor shape must survive tmux resets

**Why:** tmux or terminal focus transitions can reset DECSCUSR after pi-vim caches its last shape, leaving a hollow/default cursor that no longer communicates the active mode.

- **vim prompt** — the wrapper reasserts bar or block shape on every editor render instead of trusting the terminal to retain prior state.

## 2026-08-12 — idle status starts at the edge

**Why:** removing the Vim mode label exposed the spinner's idle width reservation as an unexplained gap before the first visible status.

- **statusline** — a dim static spinner frame sits flush left while idle and animates in accent color while a turn runs, eliminating the blank reservation.

## 2026-08-12 — immediate send belongs to Vim bang

**Why:** maintaining both `/send` and `:w!` duplicates one action, while the bang already combines deliberate submission with forcing the held queue.

- **vim prompt** — `:w!` submits its prompt and immediately flushes every previously held message in FIFO order.
- **send hold** — `/send` is removed; queue hints name `:w!` as the only immediate-send control.
- **requirements** — the former `/send` interface is superseded by Vim bang.

## 2026-08-12 — Vim mode belongs at the cursor

**Why:** a bar while inserting and a block while navigating communicate modal state at the exact point of attention, making a persistent statusline label redundant.

- **vim prompt** — Insert uses a hardware bar cursor; Normal, Visual, V-LINE, and EX use a hardware block cursor, with no mode label elsewhere.
- **statusline** — the far-left Vim mode segment is removed.
- **requirements** — cursor-shape mode feedback supersedes the text-indicator requirements.

## 2026-08-12 — remove passive prompt-routing features

**Why:** drafts, cross-session forwarding, and notes mode add alternate storage and delivery paths that are no longer wanted in the root Pi configuration; ordinary editor submission and explicit session work should remain the only prompt paths.

- **drafts, forwarding, and notes** — the active feature pages and sidebar entries are removed with their commands, tool, inbox transport, and storage behavior.
- **send hold and pinned questions** — all non-command editor text now follows the ordinary hold and answer rules; there are no forwarding or notes exceptions.
- **notifications, skills, docs command, testing, and roadmap** — examples and future-design notes no longer assume the removed features.
- **requirements** — the historical delivery rows are superseded by one explicit removal requirement.

## 2026-08-12 — prompt contracts need explicit test coverage

**Why:** describing prompts as untested obscures the structural assertions that protect required instructions and makes future prompt regressions less likely to receive a focused check.

- **testing** — required prompt contracts are covered by free structural assertions; only model judgement remains a live-use concern.

## 2026-08-12 — a Vim bang should mean send now

**Why:** once EX `:w` is the deliberate submission gesture, its standard force variant is the natural fast path for prompts that do not need the send hold.

- **vim prompt** — EX `:w!` and `:W!` submit the current prompt and immediately flush all held messages in FIFO order.
- **send hold** — the Vim bang is equivalent to submitting the prompt and then running `/send`.

## 2026-08-12 — Vim wrapping must preserve every clipboard path

**Why:** moving modal submission and mode display into a wrapper must not break
Pi's terminal paste or system clipboard integration, nor pi-vim's yank and put.

- **vim prompt** — clipboard behavior is required to survive wrapper composition.
- **requirements** — bracketed paste, Ctrl+V text paste, yank mirroring, and put
  are tracked as independently exercised paths.

## 2026-08-12 — Vim mode belongs in the statusline

**Why:** a separate mode row spends vertical editor space on persistent state
that the statusline already exists to carry.

- **vim prompt** — the editor mode row is removed; colored INSERT, NORMAL,
  VISUAL, V-LINE, and EX state is the far-left statusline segment.
- **requirements** — the prior above-prompt placement is superseded by statusline
  placement before every existing segment.

## 2026-08-12 — account allowance should identify the active model's provider

**Why:** several Burn allowances appear together, so the relevant one should be visible without mentally mapping the selected Pi model to a separate provider alias.

- **statusline** — `*` marks the Burn provider related to the active model, with explicit Codex and OpenCode mappings and no guessed marker for unrelated providers.
- **requirements** — active-provider marking is independently tracked through mapping, rendering, and live verification.

## 2026-08-12 — Return should compose, not disappear

**Why:** the Vim wrapper correctly prevented plain Return from submitting, but swallowed the key entirely, making multiline prompt composition impossible despite the configured newline binding.

- **vim prompt** — plain Return in Insert mode inserts a newline and still never submits; EX Return retains command execution.
- **requirements** — multiline Return behavior is tracked independently from the EX-only submission policy.

## 2026-08-12 — usage icons need breathing room

**Why:** tightly joined glyphs and values such as `↺93%` read as one noisy symbol in the footer instead of a scannable icon followed by a measurement.

- **statusline** — input, output, cache, cost, and context icons each have one space before their numeric value.
- **requirements** — icon/value spacing is tracked through rendering and live pane verification.

## 2026-08-12 — routine safeguards and context controls should be automatic

**Why:** agent-run Git must not hang or bypass repository checks, a large skill inventory needs an explicit way to control permanent prompt eligibility, and compaction should not strand work waiting for another user message.

- **toolchain** — Git tool calls run without interactive editors, cannot use `--no-verify`, and honor project `ship.sh` workflows.
- **skills** — `/toggle-skills` searches discovered skills, safely changes their model-invocation frontmatter, and reloads after applying.
- **sessions** — successful compaction reconstructs the active branch and automatically continues its unfinished task.
- **requirements** — Git interception, skill toggling, and post-compaction continuation are independently tracked.

## 2026-08-12 — Vim prompt behavior belongs to the home configuration

**Why:** submission keys and editor-state presentation are personal Pi behavior;
keeping them in one project made the editor inconsistent elsewhere, and placing
the mode below the prompt made state arrive after the thing it describes.

- **vim prompt** — new page. The global pi-vim wrapper makes EX `:w`/`:W` the
  only submission path, keeps EX `:q`, and renders the compact colored mode label
  above the prompt's top border in every working directory.
- **requirements** — global ownership and above-input rendering supersede the
  project-local wrapper and Ctrl+Enter submission behavior.

## 2026-08-11 — provider usage should scan in priority order

**Why:** full provider names consume footer space, and snapshot order hides which CLI allowance is currently under the most pressure.

- **statusline** — provider allowances are ordered from most to least used and use stable CLI aliases: `CC`, `CC2`, `OC`, and `CX`.
- **requirements** — the all-provider allowance requirement now includes usage ordering and compact CLI aliases.

## 2026-08-11 — account usage should not advertise its implementation

**Why:** the user wants a compact comparison of how much allowance every provider has used; command names and dollar spend add noise, while showing only the active provider hides routing options.

- **statusline** — account usage renders every healthy provider as `<provider> <used>%`, using its most-used active limit, without a `burn` label or dollar spend.

## 2026-08-11 — provider allowance should be visible before it blocks work

**Why:** session-local cost does not reveal the subscription or provider allowance shared across sessions, even though `burn` already maintains that account-level view.

- **statusline** — the right-aligned usage block reads the cached `burn --json` snapshot once per minute and shows the active provider's observed spend, when available, plus its most-used active limit; snapshot failures stay quiet and never trigger a paid refresh.
- **requirements** — active-provider account spend and usage in the footer is tracked independently from Pi session spend.

## 2026-08-11 — agent work should be watchable as it happens

**Why:** session transcripts preserve the facts but not a legible, cinematic view of chat, edits, tools, output, and task progress unfolding together.

- **animate** — new page. `/animate` attaches a typed append-only recorder to the current Pi session and opens South’s live, scrub-capable GSAP replay.
- **requirements** — live recording, typed component mapping, sticky todos, continuous code/chat typing, and full replay are tracked as one independently verifiable command.

## 2026-08-11 — bare startup should recover work by default

**Why:** most Pi launches continue existing work, and silently creating another empty session makes conversations easy to strand; explicit CLI session choices should remain non-interactive.

- **sessions** — bare interactive `pi` asks Resume or New session with Resume selected by default, while explicit session, mode, fork, and prompt arguments bypass the chooser.
- **install** — `stage-03.sh` installs the tracked launcher at `~/.local/bin/pi`, ahead of the real Pi binary, so explicit invocations pass through without recursion.
- **requirements** — startup selection is tracked independently from in-session resume and fork behavior.

## 2026-08-11 — side quests need explicit context and model boundaries

**Why:** remembered side work should run concurrently without creating a conversation branch, but silently guessing which transcript and model it inherits makes delegation unpredictable.

- **sessions** — `/btw` launches a non-persistent writable background child, asks whether to use parent, no, or another session's context, then asks which configured model to use; `/fork` remains the operation that actually forks a session into a right-hand pane.
- **requirements** — the earlier pane-copy interpretation is superseded by explicit non-forking side-quest behavior.

## 2026-08-11 — side-work syntax should sound like an aside

**Why:** the workflow is used when the user remembers something “by the way” during another task, so `/btw` is faster and more natural than describing the implementation as background work.

- **sessions** — `/btw <task>` is the command for launching a writable copied session in a right-hand tmux pane; `/background` is no longer registered.
- **requirements** — the command rename is independently tracked so the old spelling cannot linger unnoticed.

## 2026-08-11 — remembered side work should branch without interrupting the active task

**Why:** a related task remembered mid-flow needs the current conversation context but should not replace, steer, or block the work already underway; the footer should also keep changing usage figures in one predictable place and avoid advertising MCP servers that have not loaded.

- **sessions** — `/fork` selects a branch point and opens the copied session in a right-hand tmux pane named `Copy of <current session>` while preserving focus on the original; `/background <task>` copies the current leaf and starts a writable task there.
- **statusline** — token input/output, cache, cost, and context are grouped at the right edge; only connected MCP names appear, capped at three plus `+N others`; branch, cwd, elapsed time, and the generic LSP-loaded marker leave the footer.
- **requirements** — background copies, tmux-preserving forks, right-aligned usage, and connected-only MCP summaries are tracked independently because each can fail on its own.

## 2026-08-11 — composing and reading state should not require hidden conventions

**Why:** plain Enter submitted drafts unexpectedly, while border colours and a bare permission dot encoded important state with no visible legend; recent skill history also spent scarce footer width on a redundant noun.

- **keybindings** — Enter inserts a newline and Ctrl+Enter submits; pi-vim follows those actions in Insert mode, while EX-mode Enter keeps its command semantics.
- **send hold** — Ctrl+Enter is no longer a flush shortcut; it submits through the normal hold path, and `/send` alone flushes an existing queue.
- **statusline and dashboard** — skill history moves out of the footer into `/dash`, where it shows the two newest values plus `+N more`; configured models use compact stable aliases; permission uses `●!`/`●?`/`●–`, and thinking is a separate `◇level` value that explains the input-border colour.
- **requirements** — explicit submission and self-explanatory editor/footer state are tracked separately and require live keyboard and pane evidence.

## 2026-08-11 — the default surface should be a lean coding assistant

**Why:** the approved lean cut removes duplicate discovery paths and convenience layers while keeping the capabilities that directly improve coding; the statusline should spend columns on values rather than labels.

- **intro** — Pi starts from clear coding requests without a mandatory project questionnaire, asks only on genuine ambiguity or plausible wrong-project mistakes, and delegates only bounded read-heavy work.
- **modes and keybindings** — read-only permission mode plus structured todos replace the duplicate vendored plan mode and its shortcut.
- **install and skills** — native updating replaces `pi-updater`; canonical third-party skills live only under `~/.agents/skills`, and the 207 MB skill-toggle extension is replaced by built-in `pi config`.
- **docs command and skills** — live demos use `/skill:demo` or natural language instead of a thin `/demo` wrapper; configuration improvements are ordinary scoped coding requests instead of a thin `/improve` wrapper, so the dedicated improve page is removed.
- **subagents** — new page. One provider-generic, read-only tool runs up to four independent investigations with the parent's selected Pi model and reports delegated usage.
- **toolchain and roadmap** — native search, LSP, and bounded read-only delegation form the coding tool hierarchy; future coordination extends this model rather than adding parallel writers.
- **statusline** — a coloured dot replaces permission text, `↺` replaces `cache`, and `◫` replaces `ctx`, preserving the values while saving columns.
- **testing** — prompt checks now enforce coding-first behavior without the startup questionnaire, and subagent parsing/failure boundaries are covered without paid turns.
- **requirements** — the approved cleanup, coding toolset, generic subagents, coding-first prompt, and compact status icons are tracked independently; superseded prompt and plan-mode requirements are withdrawn.

## 2026-08-11 — configuration cleanup needs an explicit approval boundary

**Why:** the coding configuration has accumulated duplicate discovery paths, convenience layers, and startup policy, but removing an intentional workflow without first naming it would trade bloat for surprise.

- **requirements** — the requested bloat removal, coding toolset, provider-generic subagents, and concise coding-first prompt are tracked separately; removal remains open until the user approves the audited cut.

## 2026-08-11 — routine maintenance should cover every installed toolchain

**Why:** updating only Fedora, Flatpak, and the coding-agent binaries left firmware, language servers, editor plugins, shell plugins, and manually installed Rust, Go, and npm tools to drift independently; rebuilding the DNF-owned Ghostty binary also bypassed package ownership.

- **install** — the tracked package updater runs as the desktop user, delegates only system work to `sudo`, and covers the installed system, agent, language, editor, shell, firmware, and AppImage update paths.

## 2026-08-11 — repeated session summaries should be instant

**Why:** a TLDR is useful for recovering the current direction, but re-summarizing an unchanged transcript spends time and tokens to rediscover the same answer.

- **session TLDR** — new page. `/skill:tldr` summarizes the active branch through a usage-accounted tool; branch-scoped session entries cache the result, meaningful-conversation fingerprints skip unchanged work, and cache misses request long provider prompt retention.
- **skills** — `tldr` is explicitly invoked, adds no permanent skill-body context, and terminates on the cached tool result.
- **requirements** — cached TLDR behavior is delivered with six focused regressions, the full 104-test and free e2e suites, idempotent installation, a production docs build, and a live pane proving refresh, unchanged cache hit, and cache restoration after `/reload`.
- **testing** — pure regressions cover TLDR snapshot exclusions, meaningful-change fingerprints, cache restoration/reuse, and prompt structure.

## 2026-08-11 — active workflows should remain visible

**Why:** progressive skill loading keeps full instructions out of the base prompt, but it also makes the workflows already brought into the current session easy to forget.

- **statusline** — up to three recently loaded unique skills appear oldest-to-newest; successful `SKILL.md` reads and `/skill:name` invocations move a skill to the newest position.
- **requirements** — session skill recency is delivered with recognition, recency/deduplication and restoration regressions, a passing free e2e suite, and a fresh pane capture.
- **testing** — pure tests cover skill recognition, three-item recency, deduplication, restoration, and status formatting.

## 2026-08-11 — language-server health should stay glanceable

**Why:** the global status line needs to expose which semantic servers are available without letting a verbose LSP segment compete with the model, permissions, spend, or context figures.

- **statusline** — the single `LSP ✓` loaded indicator is reserved for the far-right edge and disappears with the rest of the low-priority side on narrow terminals.
- **lsp** — individual server names and activity are omitted from the footer; actionable failures stay in tool results, and the loaded indicator does not duplicate itself in the general extension-status area.
- **requirements** — the minimal far-right LSP indicator is delivered with a placement regression, passing free e2e extension load, and a fresh pane capture.
- **testing** — a layout regression proves the LSP indicator is excluded from general extension statuses and returned only for the far-right slot.

## 2026-08-10 — `/docs` should open where changes are recorded

**Why:** opening the documentation at its introduction adds a navigation step when the default reason to open it is to inspect the latest configuration change, and the old port no longer matches the shared local-docs convention.

- **docs-command** — bare `/docs` serves on port 3565 and opens `/changelog`; explicit page matching and `/docs stop` remain unchanged.
- **skills** — newly bootstrapped project `/docs` extensions use the same shared changelog URL instead of deriving a project-specific port.
- **requirements** — the exact default URL is tracked and requires real command/server evidence.

## 2026-08-10 — Claude no longer belongs in the Pi configuration

**Why:** the custom Claude provider and persistent Claude subagent bridge duplicate
agent paths the user no longer wants to maintain, while their model entries,
status/accounting hooks, tests and documentation keep the integration present even
when nobody calls it.

- **models** — the scoped cycle contains no Claude Code models and the credentials section no longer treats Anthropic as a configured provider.
- **stats and statusline** — session reporting is provider-generic and no longer tracks, colours or advertises Claude subagents.
- **testing** — free and paid verification exercise Pi itself without requiring Claude binaries, registrations, credentials or turns.
- **intro, MCP and skills** — active configuration documentation no longer points to a Claude bridge, Claude Code host configuration or Claude-owned skill paths.
- **agent usage, Claude as a model and Claude subagents** — the current feature pages are removed; append-only requirement and changelog entries remain as historical evidence rather than active behavior.
- **requirements** — removal is tracked separately from the earlier delivered requirements it supersedes.

## 2026-08-10 — wrong-project prompts should be caught before they cause work

**Why:** the user sometimes submits a request in the wrong Pi conversation. A directory name is not enough context to detect that mistake, so each new interactive conversation needs an explicit project brief and later requests need a targeted sanity check before tools can affect the wrong repository.

- **intro** — every new interactive conversation asks what kind of project this is and what it is for before doing project work; later requests that plausibly belong to another project require confirmation, while normal cross-cutting work proceeds without repeated challenges.
- **requirements** — establishing a project brief and confirming plausible wrong-project prompts are tracked as separate behaviors because each can fail independently.
- **testing** — the free e2e suite prevents either global prompt instruction from disappearing; whether the model applies those judgment-based instructions is still verified in a fresh conversation rather than inferred from a string check.

## 2026-08-10 — shell work should use the global agent toolchain efficiently

**Why:** Pi's native tools are compact and structured, but coding work still needs shell commands for broader searches, structured data, diffs and HTTP. Without an explicit precedence, agents can fall back to slower or noisier legacy commands even when modern binaries are available globally.

- **toolchain** — new page. Pi prefers native bounded tools when they fit, then uses `rg`, `fd`/`rg --files`, `jq`, `yq`, `git`/`delta`, `curl`, and syntax-aware search with explicit limits, no captured ANSI or pagers, and normal ignore behavior.
- **requirements** — global agent-toolchain use is tracked as a separately verifiable Pi requirement.

## 2026-08-10 — model selection should remain explicit

**Why:** automatic request classification and model switching made routing harder to predict than choosing a model directly, and the user no longer wants that layer in the editor.

- **drive** — the `/drive` command, automatic/manual routing, route status, classifier, tests, and dedicated documentation are removed; prompts use the model and thinking level selected through Pi itself.
- **requirements** — the original routing requirement is withdrawn and removal is tracked explicitly.
- **send-hold** — held prompts no longer document a routing interaction that does not exist.
- **stats** — model statistics stand on their own rather than feeding a retired routing table.
- **docs-command** — page-matching examples use pages that remain installed.
- **testing** — the interactive-flow inventory no longer names the retired routing picker.
- **notifications** — deliberate silence examples name only installed interactive flows.
- **claude-subagents** — the slash-command example names only commands that remain installed.

## 2026-08-10 — todo progress needs one home

**Why:** the active todo list is already visible in the widget directly above the editor, so repeating its compact count in the statusline adds noise without adding information.

- **todo** — unfinished progress is shown in the above-editor widget and no longer publishes a duplicate statusline segment.
- **statusline** — todo is excluded from extension statuses because its progress is already visible beside the editor.
- **requirements** — removing duplicate todo progress is tracked as a separately verifiable requirement.

## 2026-08-10 — diff structure should not erase source structure

**Why:** Pi's edit renderer painted every added source line with one diff foreground colour, so keywords, strings and function names were indistinguishable even though the file language and syntax palette were available.

- **code-rendering** — edit cards keep diff-coloured gutters and markers while rendering source tokens in the file language's Rose Pine syntax colours.
- **requirements** — preserving syntax colour inside rendered edit diffs is tracked as a separately verifiable requirement.

## 2026-08-10 — improvement belongs in the conversation that requested it

**Why:** spawning another Pi process discarded the context that made the improvement request meaningful and turned a simple guided workflow into a second agent to monitor. The user wants the current agent to improve the configuration with them.

- **improve** — `/improve` now starts its guided, direction-first workflow as a turn in the current session; the separate session, tmux window, logs, list and view interface are retired.
- **intro** — the enforced docs-first workflow describes in-session improvement rather than a fresh self-review agent.
- **sessions** — `/improve` no longer claims or creates a separate session store.
- **housekeeping** — the `improve` store is documented only as cleanup for legacy conversations and logs.
- **requirements** — the old fresh-agent requirement is withdrawn and same-session execution is tracked independently.

## 2026-08-10 — improvement starts with an outcome, not a speculative audit

**Why:** `/improve` treated an unqualified request as permission for an exhaustive repository audit, so a fresh agent began expensive, unfocused work before learning what the user wanted improved. The improver should spend its clean context on the user's actual pain point.

- **improve** — text after `/improve` supplies initial direction; without a concrete outcome, pain point or area, the fresh agent asks one focused question and waits. It scopes reading and changes to that direction, and performs a broad audit only when explicitly requested.
- **requirements** — direction-setting before investigation or edits is tracked as a separately verifiable `/improve` requirement.

## 2026-08-10 — a new session should start without an artificial pause

**Why:** the send hold is an undo window for follow-up work, but applying it before a new session has done anything makes every kickoff feel delayed when there is no active context to protect.

- **send-hold** — the first ordinary prompt in an empty session bypasses the countdown once; existing, resumed, reloaded and history-bearing forked sessions retain normal hold behavior.
- **requirements** — first-prompt bypass is tracked separately from the existing FIFO queue guarantee.

## 2026-08-10 — semantic navigation should not require shell-command guesswork

**Why:** text search can find spellings but cannot reliably answer where a symbol is defined, how it is typed, which references resolve to it, or which diagnostics the compiler sees. Pi needs direct read-only language intelligence for the user's primary Go and TypeScript work.

- **lsp** — new page. One lazy, session-scoped `lsp` tool provides hover, definition, references, document symbols and diagnostics through `gopls` and TypeScript's native Go server (`tsgo`), with one-based positions, request timeouts and no mutating actions.
- **install** — `gopls` and `@typescript/native-preview` are documented machine prerequisites rather than Pi packages.
- **requirements** — read-only Go and native-TypeScript LSP support is recorded separately from generic file and shell tools.
- **testing** — protocol framing, server selection, positions and result formatting are unit-tested; e2e requires both configured server binaries to run.
- **roadmap** — the broader oh-my-pi tool inventory is a capability backlog, ordered from code intelligence and structural search through runtime, coordination, desktop and durable memory work, with prompt-cost and permission constraints.

## 2026-08-10 — configuration upgrades must not leave command-time API failures behind

**Why:** Pi 0.84.1 exposed two model-changing calls on the extension API rather than the event context, but load-only smoke tests could not detect the resulting runtime exceptions. The same audit found that documented model defaults and automatic file discovery had drifted from the tracked configuration.

- **drive** — routing changes models through the installed extension API, records a route only after the switch succeeds, and treats HTTP 402/429 provider responses as session-local exhaustion signals.
- **models** — the documented model cycle and low startup thinking level match the tracked settings, including Claude Code and OpenRouter entries.
- **install** — `link.sh` discovers tracked extensions, themes, and skills instead of requiring a second hard-coded inventory.
- **requirements** — the Pi 0.84.1 configuration audit is delivered with runtime, link, 88-unit, full-e2e, and live-tmux evidence.

## 2026-08-10 — drive should make the routing decision instead of delegating it back to the user

**Why:** a routing assistant that interrupts every request with a category picker adds repeated work precisely where it is supposed to remove it; explicit questions remain useful only as an opt-in diagnostic or override.

- **drive** — enabled drive classifies request category and focused-change scope automatically without spending model tokens; `/drive manual` is the explicit opt-in for the existing question flow, `/drive auto` restores automatic mode, and the active mode stays visible.
- **requirements** — automatic no-dialog routing is delivered with deterministic classifier and input-path tests, full e2e, and paired live panes proving automatic routing versus explicit manual questions.

## 2026-08-10 — session spend needs a chronological explanation

**Why:** totals and per-model aggregation cannot answer which individual step was slow or expensive. The transcript already owns provider usage, so a useful history should add measured elapsed time without creating a second accounting source that can drift.

- **stats** — `/costs` opens a branch-scoped model/tool timeline with elapsed time, token categories, per-step cost and cumulative spend; new timing records persist in-session while older steps use visibly estimated adjacent-message timing.
- **requirements** — per-step token, cost and elapsed-time history is delivered with projection/timing regressions, full e2e, and a live overlay showing exact and visibly estimated durations.

## 2026-08-10 — copying a rendered snippet should be one action

**Why:** selecting a multiline Bash/Python card by dragging is unnecessarily precise, while Pi’s extension interface provides no clickable or double-clickable transcript regions. The available affordance should still be visible where the code appears.

- **code-rendering** — Bash cards advertise `Ctrl+Alt+C copy`; that shortcut and `/copy-code` copy the most recent rendered Bash command or fenced snippet.
- **keybindings** — `Ctrl+Alt+C` is the snippet-copy shortcut.
- **requirements** — one-step snippet copying is delivered with selection regressions, full e2e, a live shortcut, and exact X11 clipboard evidence.

## 2026-08-10 — a token cap should lead to a decision, not a dead end

**Why:** reaching a hard token cap can mean waiting for capacity, moving the work to another model, or stopping intentionally. Silently discarding the blocked prompt forces the user to reconstruct both the decision and the work.

- **guardrails** — the hard-token-cap path retains the blocked prompt and offers pause-and-retry, model switch with a redacted Matt Pocock handoff, or cancel; dollar caps remain direct blocks.
- **requirements** — the token-cap decision flow is delivered; regressions cover pause, handoff switch, allowance reset and cancel, and a live pane shows both decision stages.

## 2026-08-10 — timed pause needs an explicit scope

**Why:** the requested `/pause` duration picker is clear about presets and custom input, but “pause” could mean interrupting active work or delaying future work. That semantic choice must be visible rather than silently guessed.

- **guardrails** — `/pause` lets the active turn finish, queues future work, survives reload/resume, exposes 5m/15m/1h/custom choices, and resumes FIFO work automatically at expiry; model switching at a token cap restarts the same allowance for the selected model.
- **requirements** — pause and token-cap recovery are delivered with guardrail/send-hold regressions, full e2e, and live preset, queued-pause, reload-restoration, decision-menu and model-picker evidence.

## 2026-08-10 — release held work with `/send`

**Why:** `/send` states the action more directly than `/now`, and a modified Enter shortcut makes the fast path available without opening slash autocomplete.

- **send-hold** — `/send` is the immediate FIFO release command and `Ctrl+Enter` is its terminal-supported keyboard alias; the old `/now` and `/force` names are no longer part of the interface.
- **keybindings** — `Ctrl+Enter` releases held prompts immediately.
- **requirements** — the command rename and shortcut are delivered with 15 queue regressions and a live `Ctrl+Enter` handler probe.

## 2026-08-10 — outstanding questions stay beside the editor

**Why:** a question that exists only in the transcript can scroll out of sight while the user investigates or the session continues, leaving the agent blocked on an invisible decision.

- **questions** — new page. The agent pins outstanding questions in a session-scoped widget above the editor; an ordinary answer clears it, commands and forwards preserve it, and `/questions clear` is the explicit escape hatch.
- **requirements** — persistent outstanding-question visibility is delivered with lifecycle regressions and a live pane proving restore and answer-time clearing.

## 2026-08-10 — settle the three pending editor choices

**Why:** autocomplete height, todo persistence and duplicate skill ownership had deliberately awaited user decisions. The user approved a shorter menu and delegated the two architecture choices, so the configuration now needs one unambiguous contract for each.

- **keybindings** — slash autocomplete shows at most 10 rows, limiting transcript displacement while retaining paged access to longer result sets.
- **todo** — one title-derived file per list is canonical because independent updates avoid whole-session rewrites and isolate malformed or hand-edited plans.
- **skills** — the lockfile-backed `mattpocock/skills` installation under `~/.agents` is the canonical `grill-me`; Pi must not link a divergent duplicate.
- **intro** — the tracked skills inventory distinguishes configuration-owned skills from globally discovered third-party skills.
- **requirements** — all three decisions are delivered: 10-row live autocomplete, separate current-session todo files, and a collision-free pane using the sole upstream `grill-me`.

## 2026-08-10 — usage snapshots are private by default

**Why:** the JSON and dashboard included account email addresses even though identity was irrelevant to deciding where capacity remained. Privacy should fail closed: ordinary commands must produce a share-safer snapshot, while retaining sensitive detail requires an explicit choice.

- **agent-usage** — `collect`, `serve`, and `spend` default to identity scrubbing. `--scrub strict` also removes granular model/provider and usage history; `--no-scrub` explicitly retains normalized identity details. Every snapshot declares its privacy mode, and a server never serves an older file at a weaker privacy level than requested.
- **requirements** — default identity scrubbing and strict/full controls are delivered with live JSON, legacy-file, fail-closed downgrade, dashboard-refresh, and real-browser evidence.

## 2026-08-10 — the usage JSON gets a direct command

**Why:** the collector and dashboard produced a useful private JSON file, but reaching it still required remembering a long cache path or collector invocation. The requested shell command should open the existing artefact without unexpectedly recollecting every time.

- **agent-usage** — `spend` opens `~/.cache/agent-usage/usage.json` in `$VISUAL`, `$EDITOR`, or `nvim`; it collects only when the file does not exist. Dashboard Refresh or the explicit collector remains the way to update an existing snapshot.
- **install** — `stage-03.sh` links the tracked `spend` executable into `~/.local/bin`, which is already on the configured shell path.
- **requirements** — the `spend` command is delivered with direct symlink, missing-snapshot, private-file-mode, and live nvim evidence.

## 2026-08-10 — rendered code needs language-aware colour

**Why:** live Bash tool cards showed shell commands and embedded Python heredocs as one flat block colour, making structure harder to scan and defeating the syntax palette already defined by the theme.

- **code-rendering** — new page. Bash tool calls use shell highlighting, heredoc bodies switch to a language resolved from their interpreter, target filename or conventional delimiter, and unlabelled Markdown fences are inferred only from conservative signatures. Unknown code stays plain rather than accepting a confident wrong guess.
- **requirements** — syntax highlighting is delivered with parser regressions, full e2e, and a live pane showing Bash, embedded Python, and inferred Markdown fences in distinct Rose Pine syntax colours.

## 2026-08-10 — visual verification catches `/dash` before rendering

**Why:** the first real pane capture of `/dash` did not show an overlay; it exposed a command-time API error instead. After that was fixed, scrolling the real overlay exposed tool names joined with no gap. Extension loading could catch neither defect, so the standard suite needed a real command probe and rendered features needed the missing visual evidence recorded explicitly.

- **testing** — the TypeScript test command and e2e suite run every `*.test.ts`; a real Pi RPC probe invokes `/dash` up to its renderer while tmux remains mandatory for the rendered result.
- **requirements** — `/dash`, `/drive`, `/draft`, the current statusline and a real dunst toast now have named live evidence; automatic hidden-pane notification triggering remains partial rather than being inferred from the test toast. A reload-time `grill-me` collision with the separately discovered `~/.agents` copy is recorded as open pending a canonical-source decision.

## 2026-08-10 — forwarding delivery is evidence, not an assumption

**Why:** forwarding had proved that inbox writes were not lost, but had never proved that a running destination consumed one into its TUI. Persistence and delivery are separate claims and the ledger needed to stop carrying the latter as unresolved once it was observed.

- **requirements** — live `<<<<` delivery is done: a fresh source selected a fresh named target, the target displayed the sender and forwarded prompt, the inbox was consumed, and the target transcript recorded exactly one forwarded user message.

## 2026-08-10 — send-hold survives the real Pi lifecycle

**Why:** reviewing the queue against Pi’s installed extension API found defects that the fake single-extension harness could not expose: timers survived session replacement, extension-injected releases could be swallowed or classified twice, RPC images could be dropped, `/now` forced only the first countdown, and waiting UI could stick at zero. A send safeguard must not introduce message loss or crash the editor.

- **send-hold** — the hold is TUI-only and session-scoped; all `/now` countdowns are cleared, queued work visibly waits behind an active turn, extension replays are not reinterpreted by notes or drive, and a hard spend limit pauses rather than loses the next held message.

## 2026-08-10 — requirements become recoverable state

**Why:** requests, unresolved verification and external blockers were scattered between the changelog and handoff notes, so “is everything done?” still depended on remembering a conversation. The future web-scraping request also needed somewhere durable to wait without being mistaken for current work.

- **requirements** — new append-only ledger, backfilled from the changelog and takeover handoff. It separates delivered, partial, open and externally blocked work, names required evidence, and records web-scraping tools as a future feature pending scope.

## 2026-08-10 — cross-agent usage has an honest common view

**Why:** spend and quota were scattered across four CLIs, and the routing documentation's blanket claim that no provider exposes remaining usage had become false after Codex added a read-only rate-limit API. A dashboard is only useful if it preserves the difference between billed dollars, observed local cost, and subscription utilization instead of adding unlike figures or manufacturing an OpenCode balance.

- **agent-usage** — new page. A local Alpine.js and Tailwind CDN dashboard refreshes a normalized JSON file by querying Claude and Claude2 through isolated `/usage` tmux probes, Codex through app-server JSON-RPC, and OpenCode through its own local database command. Unknown live balances remain `null`, collection is prompt-free, and per-agent failures remain visible without discarding successful data.
- **drive** — quota availability is provider-specific: Codex has a structured read interface, Claude requires an interactive usage refresh, and OpenCode Go's provider key has no live allowance endpoint. Drive remains reactive because it does not run the collector before routing.
- **requirements** — the two-account Claude quota view and refresh-driven browser dashboard are delivered with live, security and real-browser evidence. The four-agent JSON remains partial only because OpenCode Go has no authenticated live-allowance source on this machine; its unknown remaining value stays explicit rather than estimated.

## 2026-08-10 — send-hold queue documentation catches up

**Why:** the second-prompt loss bug had already been fixed in code, but its page still specified replacement-style single-message behaviour. Because these docs govern the configuration, leaving that stale would make the correct FIFO implementation look defective and tell users the wrong way to cancel queued work.

- **send-hold** — idle prompts wait in a FIFO queue; `/abort` removes only the newest, `/abort all` clears the queue, and `/now` starts flushing it. Mid-turn input bypasses the hold for Pi's steering queue.

## 2026-08-10 — demos pick their medium

**Why:** the demo skill assumed everything was a terminal program. Demoing a web page in a tmux pane, or an API by describing it, is not evidence — and the whole point of the skill is evidence. Separately, a demo that took real setup left nothing behind, so the next one rediscovered it.

- **docs-command** — `/demo` now selects the medium from what is being demoed: tmux for TUIs, a real browser via the chrome-devtools MCP server for web, `curl -i` for APIs, the database CLI for SQL, a diff for file transformations. The heuristic recorded is "what would you do to check this by hand".
- **docs-command** — the skill now writes a `demo-<thing>` skill when a demo required non-obvious setup (a dev server, seed data, a token, a viewport, a wait), and fixes an existing one that proved wrong. Explicitly does not write one for the obvious.
- **docs-command** — `/demo` no longer refuses outside tmux; it tells the agent no pane is available so a non-terminal medium is chosen instead.

## 2026-08-10 — notifications, and statusline priority order

**Why:** a permission prompt that blocks the agent is worthless on a workspace you are not looking at. Separately, the statusline had grown by accretion rather than by importance, so the things you glance at mid-task were competing for space with things you already know.

- **notifications** — new page. Toasts fire via `notify-send` when pi needs you *and* the pane is not visible. Visibility requires all three of: active pane, active tmux window, focused terminal. The terminal check resolves the focused X window to a pid and walks the parent chain of the tmux client's tty, because a terminal is the client's grandparent, not its parent. Detection failure means silent — a missed toast beats a storm of false ones.
- **statusline** — reordered most important to least, left to right. Left: working indicator, permission mode, anything demanding a decision, model, tokens, cache hit rate, cost, context. Right, outermost last: branch, working directory, MCP, duration.
- **statusline** — added cache hit rate; cost rounded to two decimals; context now reads `34%/1.0M` rather than `34% of 1.0M`; the permission mode drops the `perm:` prefix and shortens `read-only` to `ro`, since colour already carries the meaning.
- **statusline** — a narrow terminal now drops the right side entirely instead of truncating the left, so spend figures survive where a directory path does not.

## 2026-08-10 — source-of-truth skill

**Why:** the method this configuration was built with — docs as specification, a request ledger, verification rules — existed only as scattered rules inside this repository. Anyone starting a project had no way to adopt it, and the one question that proved hardest here ("did we do everything?") had no artefact behind it.

- **skills** — added `source-of-truth`, a bootstrap skill for any project. Sets up a Docusaurus site, the three standing pages, `.pi/APPEND_SYSTEM.md`, and a portable `/docs` command. Carries the verification rules as concrete cautions drawn from real failures, including that a more forgiving tool is not a verification.
- **skills** — the skill ships `assets/requirements.md`, an append-only ledger where rows are added when a request arrives rather than when it is finished, and `done` requires named evidence.

## 2026-08-10 — /docs IPv6 fix

**Why:** `/docs` failed with "server did not come up" while the site was in fact running. `docusaurus serve` binds IPv6 loopback; the check connected to `127.0.0.1` only, concluded nothing was running, started a second server that failed because the port was taken, then waited out its timeout. A raw TCP check also could not tell a live server from a socket held by a dead process.

- **docs-command** — server detection now asks over HTTP (`fetch` resolves both address families and proves the site answers) rather than opening a TCP socket. A port that is bound but not serving is reported as such, pointing at `/docs stop`, instead of timing out.
- **testing** — the detection logic moved to `lib/local-server.ts` with four regression tests that stand up real servers on `::1` and `127.0.0.1`, plus a bare TCP listener to prove a held-but-not-serving socket is distinguished from a live one.

## 2026-08-10 — reaching the docs, and showing rather than telling

**Why:** the documentation is the source of truth but there was no way to open it from the editor — an earlier exchange about `/docs` was misread as a question about command design, and the command itself was never built. Separately, "does it work" kept being answered in prose when the honest answer is a pane the user can look at.

- **docs-command** — new page. `/docs` serves the built site on port 3210 and opens Chrome, `/docs <page>` jumps to a page by loose match, `/docs stop` shuts the server down. Entirely local: no model, no billing, works offline. The server is detached so quitting pi does not close the tab.
- **docs-command** — `/demo <thing>` loads the demo skill and has the agent drive the real feature in a tmux pane, capturing the pane to confirm what happened rather than asserting success.
- **skills** — added `demo`, carrying the tmux mechanics (`split-window -P -F`, `send-keys`, `capture-pane`) and the rule that a keystroke is not evidence — the pane contents are.

## 2026-08-10 — tests, and what subagents actually receive

**Why:** the config had grown well past what a single headless smoke test could vouch for, and an audit of what Claude subagents inherit turned up a real defect — they were being handed the parent's tool list, which they cannot call.

- **testing** — rewritten. Three layers: `tests/unit.test.ts` (43 assertions, no dependencies), `tests/e2e.sh` against the real `pi` and `claude` binaries with a `--paid` tier for real turns, and a standing rule to verify anything that renders by capturing the live tmux pane. Pure logic now lives in `lib/` so tests cover shipped code rather than a copy.
- **claude-subagents** — subagents no longer receive pi's tool list or its documentation pointers. They keep the project rules, guidelines and working order, and are told explicitly that any tool or slash command named in that context belongs to the parent and is unavailable to them.

## 2026-08-10 — queue visibility, drafts, guardrails

**Why:** the send countdown lived only in the statusline, which is easy to miss in the moment right after pressing Enter. Separately, prompts worth composing carefully had nowhere to live, and an unattended session had no ceiling on what it could spend.

- **send-hold** — a widget now sits directly above the editor while a message is queued, showing the countdown, a preview, and the commands. `/now` sends immediately (`/force` kept as an alias).
- **drafts** — new page. `/draft` saves the editor for later or retrieves one, offering **edit** (loads into the editor, stays saved, re-saving updates it in place) or **send now**. Stored as plain Markdown, global rather than per-project because a good prompt is worth reusing.
- **guardrails** — new page. `/limit $5` or `/limit 500k` blocks new turns at a cap without destroying anything; `/kill` shuts down now or at a scheduled time. A limit is reversible and the session survives it — a kill is not, which is why they are separate commands.
- **statusline** — added `limit` and `kill` segments; the kill countdown ticks while idle, since that is when an unattended session burns its schedule down unobserved.

## 2026-08-10 — roadmap

**Why:** wanted-but-unbuilt work was being raised in conversation and would otherwise be lost. Recording it against the docs keeps the specification honest about what exists versus what is intended, and stops the next person re-deriving the same feasibility analysis.

- **roadmap** — new page. First entry: remote sessions. Records what already works (`ssh -t tmux attach`, a shared `sessionDir` for resume-only), the three candidate designs, that `--mode rpc` over SSH is the one that delivers it, and that the real blocker is discovery — Pi has no daemon or socket, so any picker needs an explicit host list.

## 2026-08-10 — forwarding, todos, zen

**Why:** work spans several sessions at once, and there was no way to hand something to another one without copying it by hand. Separately, multi-step work had no visible plan, so there was no way to tell how far through the agent was.

- **forwarding** — new page. `<<<<` forwards a prompt to another session via a picker, with `[clipboard]` and `[last]` placeholders; `forward_to_session` makes it work in a sentence. Delivery is through an on-disk inbox because Pi has no inter-process channel. The wrapper around a forwarded message is configurable, scoped global then project, and **blank by default** — a wrapper is a claim about context the receiving model will act on.
- **todo** — new page. `/todo <goal>` has the agent record a plan through tools; several lists can be live at once, each a JSON file scoped to the session. Live widget above the editor, `/progress` for the full picture, and `todo_read` so a compacted session can recover its plan.
- **statusline** — added the working indicator (spinner while a turn runs), the `todo 2/5` segment, and `/zen` to hide the line entirely.

## 2026-08-10 — keep project skills out of global configuration

**Why:** component extraction rules were needed only by the muxbar project; installing them globally would incorrectly impose project-specific development policy on unrelated repositories.

- **skills** — the global skill list remains limited to general Pi configuration capabilities; project-specific component rules live with their project instead.

## 2026-08-10 — send hold

**Why:** interrupting a turn after it starts leaves half-applied work behind. A wrong prompt is almost always spotted within a second or two of pressing Enter, so holding the send briefly prevents the mess rather than unwinding it.

- **send-hold** — new page. Prompts are held 5 seconds before being sent; `/abort` discards a held message, `/force` sends it now. After the window `/abort` falls back to interrupting the running turn. Nothing is billed or recorded until the hold expires.
- **statusline** — added the `hold 3s /abort` countdown segment.

## 2026-08-10 — later

**Why:** questions during setup exposed two gaps. Compaction was configured but invisible, so there was no way to tell a session had silently lost detail; and the command autocomplete showed too few rows to scan.

- **sessions** — added a session-management table covering compact / fork / tree / clone / switch / name / gc, and noted that compactions are counted. Clarified that switching sessions happens in place, in the same process, and does **not** reload the config — `/reload` or a restart does that.
- **stats** — `/stats` now reports how many times the session has compacted.
- **keybindings** — command autocomplete shows 30 rows (`autocompleteMaxVisible`).

## 2026-08-10

**Why:** the default Pi instance was configured from scratch and moved into `kickstart/dotfiles`. These pages are the specification it was built to; nothing here documents pre-existing behaviour.

Initial documentation for the default Pi instance.

- **intro** — the working order: check the docs, update them, then change the code. Documentation outranks the code.
- **install** — `link.sh` symlinks the tracked config into `~/.pi/agent`; `stage-03.sh` runs it on a fresh machine.
- **models** — `Ctrl+P` cycles a scoped list; context is shared across providers, with caching, reasoning blocks, and window size as the things that do not survive a switch. Credentials are per machine and never tracked.
- **claude-as-model** — `claude` and `claude2` registered as selectable models; selecting one makes Claude Code the primary orchestrator for the turn. Distinguished from the `claude` tool.
- **drive** — `/drive` classifies each request before routing it to a model and effort level. Routing is announced and logged. Quota is learned reactively; no provider exposes remaining subscription usage.
- **modes** — permission modes `all` / `ask` / `read-only`, plus runtime path grants that apply without a restart. Plan mode documented alongside.
- **sessions** — switching happens in place; interrupt is `Ctrl+Escape`; double-Escape forks. Session transcripts are the input/output log.
- **notes** — `/notes` logs what you type instead of sending it to a model.
- **keybindings** — the overrides, and why `Escape` was freed.
- **statusline** — one line: cwd, model (colour-coded per model), permission mode, MCP, tokens, cost, context left (colour-coded by how much remains), elapsed, branch.
- **dashboard** — `/dash` overlay showing everything the agent has; owns the `mcp n/m` segment.
- **stats** — `/stats` breaks the session down by model, tool, and subagent.
- **shell-log** — `!` commands are recorded per session; `!!` entries are marked as hidden from the model.
- **housekeeping** — Pi does not garbage-collect sessions; `/gc` reports and prunes.
- **skills** — `grill-me` and `pr-review`.
- **mcp** — figma, linear, fathom, trello, chrome-devtools, all lazy, Linear's writes gated.
- **claude-subagents** — slot pools capped at 4 for `claude` and 2 for `claude2`, with per-slot usage.
- **improve** — `/improve` hands the config to a fresh agent with its own context and a scoped view of its conversation.
- **testing** — extensions as units, the editor headless via `--mode json`, and the config itself.
