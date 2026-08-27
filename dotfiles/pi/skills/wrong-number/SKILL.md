---
name: wrong-number
description: Turn the preceding misaddressed request into a contextual prompt and copy it to the clipboard.
disable-model-invocation: true
---

Treat the user message immediately before this skill invocation as intended for another agent.

1. Rewrite that message as a self-contained prompt. Include only prior conversation context needed to resolve references, preserve constraints and decisions, identify relevant files or project state, and make the requested output clear. Preserve the user's intent and uncertainty; do not solve the request or invent missing facts.
2. Write only the finished prompt, without a preamble or Markdown fence, to `/tmp/pi-wrong-number-prompt.md`.
3. Copy it to the system clipboard and remove the temporary file:

```bash
if command -v wl-copy >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
  wl-copy < /tmp/pi-wrong-number-prompt.md
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard < /tmp/pi-wrong-number-prompt.md
else
  printf 'wrong-number: no wl-copy or xclip clipboard command found\n' >&2
  exit 1
fi
rm /tmp/pi-wrong-number-prompt.md
```

On success, reply only: `Copied the handoff prompt to your clipboard.`
