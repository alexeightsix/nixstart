---
title: /docs and live demos
---

# `/docs` and live demos

Two ways to see something rather than read about it second-hand.

## `/docs`

```
/docs           open http://localhost:3565/changelog in Chrome
/docs guardrails jump straight to a page
/docs stop      stop the local server
```

Serves the built site on port 3565 and opens the changelog by default. If the site has never been built it builds first, once.

The page argument matches loosely, so `/docs guard`, `/docs stats` and `/docs statusline` all land somewhere sensible. An unmatched name says so rather than opening the wrong page.

Entirely local — no model is involved, nothing is billed, and it works offline. The docs are the source of truth for this configuration, so reaching them has to cost one keystroke rather than a reminder to go and find them.

The server is started detached and outlives the pi session, so quitting pi does not close the tab you were reading. `/docs stop` shuts it down.

## Live demos

```
/skill:demo /dash
/skill:demo the checkout page
/skill:demo the POST /orders endpoint
```

You can also ask in ordinary language: “show me this working.” Pi loads the demo skill, which first picks the medium and then produces evidence you can inspect. The separate `/demo` wrapper was removed because skill invocation and natural language already express the same operation.

### It picks the medium

| What is being demoed | Demo in |
| --- | --- |
| TUI, editor, interactive CLI | a tmux pane |
| Web page or app | a real browser, via the chrome-devtools MCP server |
| HTTP API | `curl -i`, request shown as well as response |
| SQL or a database change | the database's own CLI, state before and after |
| Non-interactive CLI tool | run it — stdout, stderr, exit code |
| Library or pure logic | a runnable snippet, or its tests |
| Background job or queue | trigger it, then read the state it changed |
| File transformation | a diff of before and after |

The heuristic is: what would you do to check this by hand? Do that. When something spans layers, demo the layer you care about and show the one underneath as corroboration — a screenshot of a success toast is weak alone, a screenshot plus the row that appeared is not.

### The rule that matters

**Capture evidence before claiming success.** Sending a keystroke is not evidence a TUI worked; firing a request is not evidence the API did the right thing; running a migration is not evidence the schema changed. Every medium has a separate step that produces proof, and skipping it is how a confident, wrong report gets written.

A failed demo reported honestly, with the capture that proves it, is worth more than a successful-sounding paragraph.

### It grows a library

If demoing something took real setup — a dev server, seed data, a token, a viewport, a wait — the skill writes that up as a `demo-<thing>` skill so it is not rediscovered. If such a skill exists but was wrong, it gets fixed in the same pass; being sent down a wrong path is worse than having no path.

Project-specific recipes go in that project's `.pi/skills/`; general ones live with this config. Nothing is written for the obvious — a skill recording what any competent reader would do is noise that rots unread.

Terminal demos require tmux; browser, API, database, and file-transformation demos use their natural medium instead.

This is the same discipline the [testing](./testing.md) page applies to development: headless runs prove code loads, evidence proves it works.
