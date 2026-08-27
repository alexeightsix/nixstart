---
title: /todo
---

# `/todo`

Ask the agent to break work into a list, then watch it work through it.

```
/todo migrate the auth module to the new session store
/todo                     list every todo list in this session
/progress                 full status of every list
```

`/todo <goal>` asks the agent to plan the work and write it down. It does that by calling a tool, so the list is structured data rather than prose it might forget.

## Multiple lists

More than one list can be live at once — they are separate pieces of work, not one queue. Each gets its own file, named from its title:

```
~/.pi/agent/todos/<session-id>/auth-migration.json
~/.pi/agent/todos/<session-id>/flaky-tests.json
```

Lists are scoped to the session, so a different conversation has its own. `/todo` with no arguments lists them; `/progress` shows every item in every list.

One file per list is intentional. Updating a short list rewrites only that list, separate pieces of work cannot overwrite a shared session document, and a damaged or hand-edited file does not hide every other plan. This scales with the number and size of independent lists better than one ever-growing `todos.json`. Reusing the same title deliberately replaces that title's existing list.

## The file

```json
{
  "title": "auth migration",
  "created": "2026-08-10T04:41:00.000Z",
  "items": [
    { "id": 1, "text": "Move token parsing into SessionStore", "status": "done" },
    { "id": 2, "text": "Update the three call sites", "status": "in_progress" },
    { "id": 3, "text": "Backfill tests for expiry", "status": "pending" }
  ]
}
```

Statuses are `pending`, `in_progress`, `done`, and `dropped`. Dropped items stay in the file: what was deliberately not done is as informative as what was.

## Seeing it in real time

While a list has unfinished work, a widget sits above the editor showing the current item and the ones around it, updating as the agent marks progress:

```
auth migration                    2/5
  ✓ Move token parsing into SessionStore
  ▸ Update the three call sites
  ○ Backfill tests for expiry
```

Todo progress appears only in this widget while work is unfinished; the [statusline](./statusline.md) does not repeat it. `/progress` prints everything including lists that are finished or dropped.

The widget disappears when every item is resolved, so a finished list stops taking up rows.

## Tools the agent uses

| Tool | What it does |
| --- | --- |
| `todo_write` | Create or replace a list |
| `todo_update` | Change one item's status, or add an item |
| `todo_read` | Read lists back — useful after compaction has dropped the details |

`todo_read` matters more than it looks: a long session gets compacted, and the plan is exactly the sort of detail that gets summarised away. The file survives compaction, so the agent can recover what it was doing.
