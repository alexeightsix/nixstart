---
title: Pinned questions
---

# Pinned questions

When the agent needs an answer before it can continue, it records the outstanding questions with the `question` tool. A fixed widget above the editor keeps them visible even after the transcript scrolls away:

```text
Awaiting your answer
  1. Keep one file per list, or combine them?
  2. Should completed lists remain visible?
```

Several related questions can be pinned together. The widget is session-scoped and survives `/reload` or resuming the session.

Sending the next ordinary prompt clears the widget because that prompt is treated as the answer. Slash commands do not clear it, so inspecting `/dash` does not accidentally discard the reminder. `/questions` shows the pending questions in a notification, and `/questions clear` is the manual escape hatch.

This is a visibility aid, not a second conversation channel: answers still go through the normal editor and appear in the transcript.
