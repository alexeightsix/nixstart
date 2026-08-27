---
title: Keybindings
---

# Keybindings

`keybindings.json` overrides Pi's defaults. Everything not listed here keeps its built-in binding; `/hotkeys` shows the full list, and `/reload` applies edits without restarting.

## Overridden

| Key | Action | Why it differs |
| --- | --- | --- |
| `Ctrl+Escape` | Interrupt | Interrupt must be explicit. A bare `Escape` no longer aborts a turn. |
| `Ctrl+Alt+S` | Session picker (`/resume`) | Unbound by default |
| `Ctrl+Alt+N` | New session | Unbound by default |
| `Ctrl+Alt+F` | Fork session | Unbound by default |
| `Ctrl+Alt+T` | Session tree | Unbound by default |
| `Enter` | Insert a newline | Multiline drafting is the default; an unmodified Return never sends. |
| `Ctrl+Enter` | Submit the prompt | Sending requires the explicit modified key. |

Freeing `Escape` is what makes double-Escape available for forking — see [Sessions](./sessions.md#forking).

## Added by extensions

| Key | Action |
| --- | --- |
| `Ctrl+Alt+A` | Cycle permission mode |
| `Ctrl+Alt+C` | Copy the most recent rendered code snippet (`/copy-code`) |

The `Ctrl+Alt+` prefix is reserved for session and mode actions, so it does not collide with the editor's own bindings.

## Kept from Pi

| Key | Action |
| --- | --- |
| `Ctrl+L` | Model selector |
| `Ctrl+P` / `Shift+Ctrl+P` | Cycle scoped models |
| `Shift+Tab` | Cycle thinking level; the input border changes to that level's theme colour and the footer names it as `◇level`. |
| `Ctrl+O` | Collapse/expand tool output |
| `Ctrl+T` | Collapse/expand thinking |
| `Ctrl+X` | Copy last assistant message |
| `Alt+Enter` | Queue a follow-up message while working |

## Autocomplete

Typing `/` opens the command autocomplete. It shows at most 10 rows — `autocompleteMaxVisible` in `settings.json` — so opening it does not push a large section of the transcript out of view. Longer result sets remain reachable by paging.

## Vim mode

The `pi-vim` package provides modal editing in the prompt. It honors Pi's configured input actions in Insert mode: `Enter` inserts a line and `Ctrl+Enter` submits. Enter inside Vim's EX mini-mode still executes the pending EX command rather than editing the prompt.
