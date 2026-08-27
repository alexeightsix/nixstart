---
name: demo
description: Show the user a feature working, in whatever medium fits it — tmux for terminal programs, a real browser for web UI, curl for APIs, a database client for SQL. Use when asked to demo, show, or prove something works.
---

Show it. Do not describe it.

A demo that is a paragraph of prose is not a demo. Produce evidence the user can look at, in the medium they would use to check it themselves.

## Pick the medium first

Ask what the user would do to verify this by hand, and do that.

| What is being demoed | Demo in | Evidence |
| --- | --- | --- |
| TUI, editor, interactive CLI | tmux pane | `capture-pane` output |
| Web page or app | real browser via the chrome-devtools MCP server | screenshot, plus console and network when relevant |
| HTTP API | `curl -i` | status line, headers, body |
| SQL or a database change | the database's own CLI (`psql`, `mysql`, `sqlite3`) | the rows, before and after |
| Non-interactive CLI tool | run it | stdout, stderr, exit code |
| Library, function, pure logic | a runnable snippet or its tests | the run output |
| Background job, queue, daemon | trigger it, then read the state it changed | log lines or the changed record |
| File transformation | run it on a real input | a diff of before and after |

When something spans layers — an API that writes a row, a button that calls an endpoint — demo the layer the user cares about and show the layer underneath as corroboration. A screenshot of a success toast is weak on its own; a screenshot plus the row that appeared is not.

If nothing fits, say what you are going to do and why before doing it.

## Terminal programs — tmux

```bash
pane=$(tmux split-window -h -P -F '#{pane_id}' -c <working-dir>)
tmux send-keys -t "$pane" 'pi' Enter
sleep 2
tmux capture-pane -p -t "$pane" | tail -30
```

Use `tmux new-window -n demo -P -F '#{pane_id}'` when it needs room — a full-screen TUI, or anything with widgets above the editor.

Allow time between `send-keys` and `capture-pane`: a TUI needs a moment to redraw and a model turn needs much longer. Sleep and re-capture rather than capturing once and guessing.

## Web — the browser

Drive the chrome-devtools MCP server: navigate to the page, take a snapshot to find elements, interact, screenshot the result. Check the console and network requests when the point of the demo is that something loaded, failed, or fired.

A screenshot is the deliverable. Describing what a page looks like while having the ability to show it is the failure this skill exists to prevent.

## APIs — curl

Show the request as well as the response, so the demo is reproducible:

```bash
curl -i -X POST localhost:3000/api/thing -H 'content-type: application/json' -d '{"name":"x"}'
```

Include the status line. For anything with side effects, follow with the `GET` that proves the effect landed.

## Databases — the CLI

Show the query and the rows it returns. For a change, show the state before, the statement, and the state after. Use a transaction you roll back if the demo would otherwise leave debris.

## The rule that matters

**Capture evidence before claiming success.**

Sending a keystroke is not evidence a TUI worked. Firing a request is not evidence the API did the right thing. Running a migration is not evidence the schema changed. In every medium there is a separate step that produces proof, and skipping it is how a confident, wrong report gets written.

If the evidence shows a failure, fix it and demo again. If it still fails, report that plainly and show the capture that proves it — a failed demo reported honestly is worth more than a successful-sounding paragraph.

Do not verify with a tool more forgiving than the thing being demoed. Checking a server with `curl` proves nothing about code that opens a raw socket.

## Leaving it behind

Leave the pane, the tab, and the data in place so the user can poke at it. Never close or kill what you opened unless asked. Clean up only side effects that would be harmful to leave — a test row in a shared database, a process holding a port.

## Growing this into a library

Before demoing, look for a skill that already covers this case — `demo-<medium>` or `demo-<project>` in the global skills directory, or in the project's `.pi/skills/`. If one exists, follow it.

**If none exists and the demo took real work to set up, write one.** Real work means anything the next person would have to rediscover:

- a dev server that must be running, and the exact command
- seed data, a fixture, or an account the demo depends on
- an auth token or environment variable, and where it comes from
- a pane layout, window size, or viewport the thing needs to look right
- a wait that has to happen before the evidence is meaningful
- a non-obvious way to reach the state being demonstrated

**Do not write one for something obvious.** `curl localhost:3000/health` needs no skill. A skill that records only what any competent reader would do adds noise and will rot unread.

**If a skill exists and was wrong or incomplete, fix it.** Being sent down a wrong path is worse than having no path. Update it in the same pass, while you know what was missing.

### Where it goes

| Knowledge | Location |
| --- | --- |
| Specific to one project | that project's `.pi/skills/demo-<thing>/SKILL.md` |
| General to a medium or tool | `~/kickstart/dotfiles/pi/skills/demo-<medium>/SKILL.md`, then run its `link.sh` |

Keep it to what you actually did: the commands, the prerequisites, the trap you hit. A demo recipe is worth having because it is concrete.

## Reporting

Say what you ran, paste the few lines of evidence that matter, and name the one thing to look at. Not a tour.

If you created or improved a demo skill, say which and in one line why — that is a change to how future work happens, not an implementation detail.
