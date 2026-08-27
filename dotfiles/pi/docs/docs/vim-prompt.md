---
title: Vim prompt
---

# Vim prompt

The tracked home configuration wraps the installed `pi-vim` editor in every Pi
working directory. Projects do not carry their own copy.

Pi starts in Insert mode. `Escape` enters Normal mode, and `i` returns to Insert
mode. The cursor carries that state without a persistent text label: Insert mode uses a thin bar, while Normal, Visual, V-LINE, and EX modes use a block. The wrapper reasserts the active shape on every editor render so tmux focus changes or terminal cursor resets cannot leave a hollow/default cursor behind. The global statusline and editor border contain no mode indicator.

Prompt submission is deliberately Vim-shaped:

1. Press `Escape` to enter Normal mode.
2. Press `:` to enter the real pi-vim EX line.
3. Enter `w` or `W`.
4. Press `Enter` to submit the complete prompt through the normal send hold.

Use EX `:w!` or `:W!` when the prompt is ready to go immediately. The bang submits the prompt and immediately releases it plus every message already held, skipping all remaining countdowns. It is the only immediate-send control.

No other editor key submits a prompt. In Insert mode, plain `Enter` inserts a newline without submitting; `Ctrl+Enter` remains blocked as a submission path. A Normal-mode `w` remains a motion, and Insert-mode `:w` or `:W` remains literal text. EX `:q` followed by `Enter` shuts Pi down gracefully, while Insert-mode `:q` remains literal text.

The wrapper preserves every clipboard path supplied by Pi and pi-vim:
terminal bracketed paste, `Ctrl+V` system-clipboard text/image paste, Vim yanks
mirrored to the system clipboard, and Normal-mode `p`/`P` puts.

Provided by `extensions/vim-prompt.ts`, layered over the globally installed
`npm:pi-vim` package.
