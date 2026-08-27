---
name: auto-push
description: Start continuous one-second Git commits and pushes for a target directory in the shared tmux automation session.
disable-model-invocation: true
---

# Auto push

Treat invocation as authorization to commit and push future changes in the target without another prompt.

1. Use the invocation argument as the target directory, or the current working directory when no argument was supplied.
2. Run `scripts/start.sh <target-directory>` from this skill directory.
3. Read the worker pane id from the launcher's output, confirm it with `tmux list-panes -t automations`, and capture that exact pane. Muxbar may add a sidebar and make itself the active pane, so the window default is not evidence. Success means the reported pane is running `auto-push.sh` for the requested target. When no tmux server existed, report that the launcher intentionally did nothing.

Leave the session running. The user's completion criterion is a live worker in the `automations` session, not merely a successful launcher exit.
