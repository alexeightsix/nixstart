## Keybindings

Leader is `<Space>` (both `mapleader` and `maplocalleader`).

### Files & search (Telescope)

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files — `git_files` inside a repo (incl. untracked), else `find_files` |
| `<leader>faf` | Find files including ignored/hidden |
| `<leader>fw` | Live grep with args (insert mode) |
| `<leader>faw` | Live grep including ignored/hidden |
| `<leader>fW` | Grep the word under the cursor |
| `<leader>of` | Recent files (cwd only) |
| `<leader>rg` | Registers picker |

### LSP (active on `LspAttach`)

| Key | Action |
| --- | --- |
| `gd` | Go to definition (Telescope, normal mode) |
| `<leader>fr` | Find references (Telescope, no jump) |
| `<leader>fs` | Document symbols (wide layout) |
| `<S-k>` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>fa` | ESLint "fix all" (only on eslint buffers) |
| `<leader>fd` | Format via conform (LSP fallback); also organizes imports in Go |
| `<leader>wd` | Workspace diagnostics (Telescope) |
| `<leader>t` | Show diagnostics for the current line (float) |
| `g]` | Jump to next diagnostic (wraps to first) |
| `<leader>ls` | `:LspRestart` |
| `<leader>l` | `:LspRestart` + reload buffer |
| `@l` | Insert a debug print of the word under cursor (Go/TS/JS/PHP) |
| `@cn` | Wrap `className="..."` in `cn(...)`; add missing imports in `.tsx` |

### Git (gitsigns / fugitive / conflict)

| Key | Action |
| --- | --- |
| `<S-h>` | Next hunk |
| `<S-b>` | Previous hunk |
| `gfc` | First hunk in file |
| `Q` | Stage current line (normal) / selected lines (visual) |
| `<leader>bl` | Blame current line |
| `<leader>td` | Toggle deleted lines |
| `<leader>gh` | Open current line(s) on GitHub (openingh) |

### Navigation & tools

| Key | Action |
| --- | --- |
| `<leader>e` | Toggle Oil file explorer (floating) |
| `<leader>ut` | Toggle Undotree |
| `<leader>rw` | Find & replace across project (grug-far) |
| `<leader>m` | Pick and run a Makefile target |
| `<leader>c` | Copy `path:line` of the cursor to the clipboard |
| `<leader>nc` | `cd ~/.config/nvim` and open `init.lua` |
| `<leader>gt` | Run the project's `generate-types.sh` in a scratch terminal |
| `gx` | Open URL under cursor |
| `<S-Tab>` | Cycle through the quickfix list |
| `<C-Right>` | Accept Copilot suggestion (insert) |
| `<C-h/j/k/l>` | Move between vim/tmux splits (vim-tmux-navigator) |

### Substitution helpers

| Key | Action |
| --- | --- |
| `<leader>s` (n) | Start `:%s/` |
| `<leader>s` (v) | Start `:s/` on the selection |

### Completion (nvim-cmp, insert mode)

| Key | Action |
| --- | --- |
| `<C-Up>` / `<C-Down>` | Select previous / next item |
| `<C-Space>` | Trigger completion |
| `<CR>` | Confirm selection |
| `<C-b>` / `<C-f>` | Scroll docs |
| `<C-e>` | Abort |
