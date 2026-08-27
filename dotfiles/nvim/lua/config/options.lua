vim.opt.backup = false            -- creates a backup file
vim.opt.clipboard = "unnamedplus" -- allows neovim to access the system clipboard
vim.opt.cmdheight = 1             -- more space in the neovim command line for displaying messages
vim.opt.colorcolumn = "99999"     -- fixes indentline for now
vim.opt.completeopt = { "menuone", "noselect" }
vim.opt.conceallevel = 0          -- so that `` is visible in markdown files
vim.opt.cursorline = true         -- highlight the current line
vim.opt.expandtab = true          -- convert tabs to spaces
vim.opt.fileencoding = "utf-8"    -- the encoding written to a file
vim.opt.foldexpr = ""             -- set to "nvim_treesitter#foldexpr()" for treesitter based folding
vim.opt.foldmethod = "manual"     -- folding set to "expr" for treesitter based folding
vim.opt.hidden = true             -- required to keep multiple buffers and open multiple buffers
vim.opt.hlsearch = true           -- highlight all matches on previous search pattern
vim.opt.ignorecase = true         -- ignore case in search patterns
vim.opt.mouse = ""                -- allow the mouse to be used in neovim
vim.opt.nu = true
vim.opt.number = true             -- set numbered lines
vim.opt.numberwidth = 4           -- set number column width to 2 {default 4}
vim.opt.pumheight = 10            -- pop up menu height
vim.opt.relativenumber = true     -- set relative numbered lines
vim.opt.scrolloff = 8             -- is one of my fav
vim.opt.shiftwidth = 2            -- the number of spaces inserted for each indentation
vim.opt.showmode = false          -- we don't need to see things like -- INSERT -- anymore
vim.opt.showtabline = 0           -- always show tabs
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = "yes"        -- always show the sign column otherwise it would shift the text each time
vim.opt.smartcase = true          -- smart case
vim.opt.smartindent = true        -- make indenting smarter again
vim.opt.spell = false
vim.opt.spelllang = "en"
vim.opt.splitbelow = true                  -- force all horizontal splits to go below current window
vim.opt.splitright = true                  -- force all vertical splits to go to the right of current window
vim.opt.swapfile = false                   -- creates a swapfile
vim.opt.tabstop = 2                        -- insert 2 spaces for a tab
vim.opt.termguicolors = true               -- set term gui colors (most terminals support this)
vim.opt.timeoutlen = 500                   -- time to wait for a mapped sequence to complete (in milliseconds)
vim.opt.title = true                       -- set the title of window to the value of the titlestring
vim.opt.titlestring = "%<%F%=%l/%L - nvim" -- what the title of the window will be set to
vim.opt.undodir = vim.fn.stdpath("cache") .. "/undo"
vim.opt.undofile = true                    -- enable persistent undo
vim.opt.updatetime = 300                   -- faster completion
vim.opt.wrap = false                       -- display lines as one long line
vim.opt.writebackup = false                -- if a file is being edited by another program (or was written to file while editing with another program) it is not allowed to be edited

vim.diagnostic.config({
  virtual_text = true,
  float = false,
  jump = {
    float = false,
  },
  update_in_insert = true,
})


vim.g.loaded_netrwPlugin = 0

vim.opt.winborder = 'rounded'

vim.api.nvim_set_hl(0, "GitConflictAncestor", { bg = "#444444", fg = "#f0f0f0" })
vim.api.nvim_set_hl(0, "GitConflictCurrent", { bg = "#2e5049", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "GitConflictCurrentLabel", { fg = "#ffffff", bg = "#3a6f68", bold = true })
vim.api.nvim_set_hl(0, "GitConflictIncoming", { bg = "#2e3f5e", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "GitConflictIncomingLabel", { fg = "#ffffff", bg = "#35548a", bold = true })
