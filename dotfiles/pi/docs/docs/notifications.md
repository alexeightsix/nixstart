---
title: Notifications
---

# Notifications

A prompt that blocks the agent is worthless if it is sitting on a workspace you are not on. Toasts fire in exactly that case, and stay silent otherwise.

```
/notify         toggle
/notify test    fire one now, ignoring focus, to check the path works
/notify off
```

Uses `notify-send`, so it goes through dunst like everything else on this machine. Toasts are tagged per kind, so a second one replaces the first rather than stacking.

## When it fires

| Trigger | Urgency |
| --- | --- |
| The agent needs permission mid-turn | critical |
| A turn finishes | low |

Any extension can request one by emitting `notify:attention` on the event bus. The focus check lives in one place so nothing has to reimplement it.

## What counts as "you can't see it"

Three things must **all** be true for the session to count as visible. Any one false means a toast:

1. Your pane is the active pane in its tmux window.
2. That tmux window is the active window.
3. The terminal itself has X focus.

The third is the one that matters most and is the least obvious to check. `pi` runs inside tmux inside a terminal, so the terminal is the *grandparent* of the tmux client — client to shell to terminal. Focus detection resolves the focused X window to a pid via `xprop`, then walks the parent chain of every process on the tmux client's tty looking for it. A direct parent check would report every focused terminal as somebody else's.

Toasts name where the session is (`0:1.2 (pi-)`) so you know which pane to go to.

## Deliberately silent

A question you asked for a second ago must not toast at you. Because the gate is "is this pane visible", that falls out for free: `/kill` confirmation and other interactive dialogs are triggered by you, at the terminal, so the check suppresses them with no special-casing.

## When detection is impossible

Not in tmux, no X server, `xprop` missing, no attached client — the answer is *visible*, so nothing fires. A missed toast is a smaller problem than a storm of false ones.

The exception is a detached session with no client attached at all: nobody can see that by definition, so it counts as hidden.

## Checking it works

`/notify test` bypasses the focus gate — you are by definition looking at the screen when you run it — and reports what the detector currently thinks:

```
Sent. Pane detected as hidden — other-pane.
```

That second half is the useful part: it tells you whether detection is working, not just whether dunst is.
