local telescope = require("telescope.builtin")
local print_ln = require("custom.log")
local extensions = require("telescope").extensions

-- How every file picker lists files.
--
-- `fd` reads the filesystem, which is the whole point: `git ls-files` reads the
-- INDEX, so a file deleted or renamed on disk keeps showing up in the picker
-- until you `git add` it. That reads as a stale cache and is not one -- git is
-- faithfully reporting what it was last told.
--
-- `--exclude .git` because `--hidden` would otherwise walk the object store,
-- which is thousands of files nobody wants to fuzzy-find. `.gitignore` is still
-- honoured: fd respects it by default, so this lists what `git ls-files` meant
-- to, minus the ghosts.
local find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" }

-- The repository this buffer is in, or nil outside one.
--
-- Keeps the old `git_files` behaviour of searching the whole repo rather than
-- whatever directory nvim happened to start in. `vim.fs.root` walks up from the
-- current buffer, so it also follows you into a sibling worktree; nil falls
-- through to telescope's own default of the cwd.
local function git_root()
  return vim.fs.root(0, ".git")
end

vim.keymap.set("n", "g]", function()
  local current_pos = vim.api.nvim_win_get_cursor(0)
  local diagnostics = vim.diagnostic.get(0)
  local target_diag

  for _, d in ipairs(diagnostics) do
    if d.lnum > current_pos[1] - 1 or (d.lnum == current_pos[1] - 1 and d.col > current_pos[2]) then
      target_diag = d
      break
    end
  end

  if not target_diag and #diagnostics > 0 then
    vim.api.nvim_win_set_cursor(0, { diagnostics[1].lnum + 1, diagnostics[1].col })
  else
    vim.diagnostic.jump({ float = false, wrap = false, count = 1 })
  end
end)


vim.api.nvim_create_autocmd("LspAttach", {
  callback = function()
    vim.keymap.set("n", "<S-k>", function()
      vim.lsp.buf.hover()
    end)

    vim.keymap.set("n", "@l", function()
      print_ln.setup()
    end)

    vim.keymap.set("n", "<leader>rn", function()
      vim.lsp.buf.rename()
    end)


    local function organizeImports()
      local params = vim.lsp.util.make_range_params(nil, vim.lsp.util._get_offset_encoding())
      params.context = { only = { "source.organizeImports" } }
      local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
      for _, res in pairs(result or {}) do
        for _, r in pairs(res.result or {}) do
          if r.kind == "source.organizeImports" then
            if r.edit then
              vim.lsp.util.apply_workspace_edit(r.edit, vim.lsp.util._get_offset_encoding())
            else
              print(r.command)
              vim.lsp.buf.execute_command(r.command)
            end
          end
        end
      end
    end

    vim.keymap.set("n", "<leader>fd", function()
      require("conform").format({
        lsp_format = "fallback",
        async = true
      })

      local ft = vim.api.nvim_buf_get_option(0, "filetype")

      if ft == "go" then
        organizeImports()
      end
    end)

    vim.keymap.set("n", "<leader>ca", function()
      vim.lsp.buf.code_action()
    end)

    vim.keymap.set("n", "<leader>fr", function() -- find references
      telescope.lsp_references({
        initial_mode = "normal",
        jump_type = "never",
      })
    end)

    vim.keymap.set("n", "@cn", function()
      local line = vim.api.nvim_get_current_line()
      local new_line = line:gsub('className="([^"]+)"', 'className={cn("%1")}')
      vim.api.nvim_set_current_line(new_line)

      local ft = vim.api.nvim_buf_get_option(0, "filetype")

      if ft == "typescriptreact" then
        vim.lsp.buf.code_action({
          apply = true,
          context = { only = { "source.addMissingImports.ts" }, diagnostics = {} },
        })
      end
    end)

    vim.keymap.set("n", "<leader>wd", function()
      telescope.diagnostics({
        initial_mode = "normal",
      })
    end)

    vim.api.nvim_set_keymap("n", "<Leader>ls", ":LspRestart <CR>", { silent = true, noremap = true })
    vim.api.nvim_set_keymap("n", "<Leader>l", ":LspRestart<CR>:e<CR>", { silent = true, noremap = true })


    vim.keymap.set("n", "<leader>fs", function()
      require("telescope.builtin").lsp_document_symbols({
        layout_strategy = "horizontal",
        layout_config = {
          preview_width = 0.5,
        },
        -- symbol column defaults to a fixed 25 chars, truncating long names
        -- with "…". Use 70% of the results window instead (values < 1 are
        -- treated as a fraction of the results window width by telescope).
        symbol_width = 0.7,
      })
    end)

    vim.keymap.set("n", "gd", function()
      telescope.lsp_definitions({
        initial_mode = "normal",
      })
    end)
  end,
})

vim.keymap.set("n", "gd", "<Nop>")

vim.api.nvim_set_keymap("n", "<Leader>gh", ":OpenInGHFileLines <CR>", { silent = true, noremap = true })

vim.keymap.set("n", "<leader>ff", function()
  telescope.find_files({
    cwd = git_root(),
    hidden = true,
    find_command = find_command,
  })
end)

vim.keymap.set("n", "<leader>m", function() -- run a Makefile target
  require("custom.make").pick()
end)

vim.keymap.set("n", "<leader>c", function()
  local path = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", path)
end)

vim.keymap.set("n", "<leader>rg", function()
  telescope.registers({
    initial_mode = "normal",
  })
end)

vim.keymap.set("n", "<leader>t", "<CMD>lua vim.diagnostic.open_float(0, {scope='line'})<CR>")

vim.keymap.set("n", "<S-Tab>", function()
  local quickfix_list = vim.fn.getqflist()
  local current_idx = vim.fn.getqflist({ idx = 0 }).idx
  if current_idx == #quickfix_list then
    vim.cmd("cc 1")
  else
    vim.cmd("cc " .. (current_idx + 1))
  end
end, { noremap = true, silent = true })

vim.keymap.set("n", "<leader>faf", function()
  telescope.find_files({
    cwd = git_root(),
    no_ignore = true,
    hidden = true,
    -- `--no-ignore` as well, so this really is everything except the object
    -- store -- `no_ignore` alone is not passed through to a custom command.
    find_command = vim.list_extend(vim.deepcopy(find_command), { "--no-ignore" }),
  })
end)

vim.keymap.set("n", "<leader>s", function()
  return ":%s/"
end, { expr = true })

vim.keymap.set("v", "<leader>s", function()
  return ":s/"
end, { expr = true })

vim.keymap.set("n", "<leader>faw", function()
  telescope.live_grep({
    no_ignore = true,
    hidden = true,
  })
end)

vim.keymap.set("n", "<leader>of", function()
  telescope.oldfiles({
    only_cwd = true,
    initial_mode = "normal",
  })
end)

vim.keymap.set("n", "<leader>fW", function()
  local word = vim.fn.expand("<cword>")

  if word == "" then
    return telescope.live_grep()
  end

  telescope.grep_string({
    initial_mode = "normal",
  })
end)

vim.keymap.set("n", "<leader>fw", function()
  extensions.live_grep_args.live_grep_args({
    initial_mode = "insert",
  })
end)

vim.api.nvim_create_user_command("OilToggle", function()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_filetype = vim.api.nvim_buf_get_option(current_buf, "filetype")
  if current_filetype == "oil" then
    require("oil").toggle_float()
  else
    require("oil").toggle_float()
  end
end, { nargs = 0 })

vim.keymap.set("n", "<leader>e", "<CMD>:OilToggle<CR>")

vim.keymap.set("n", "<leader>td", "<CMD>Gitsigns toggle_deleted<CR>")

vim.keymap.set("n", "<leader>bl", "<CMD>Gitsigns blame_line<CR>")

vim.keymap.set("n", "gfc", function() -- go to first uncommitted change in file
  require("gitsigns").nav_hunk("first")
end)

vim.keymap.set("n", "<S-h>", function() -- go to next git change
  require("gitsigns").nav_hunk("next")
end)

vim.keymap.set("n", "<S-b>", function() -- go to previous git change
  require("gitsigns").nav_hunk("prev")
end)

vim.keymap.set("n", "gx", "<CMD>URLOpenUnderCursor<CR>")

vim.keymap.set("n", "<leader>ut", "<CMD>:UndotreeToggle<CR>")

vim.keymap.set("n", "<leader>gt", function()
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.termopen("bash " .. vim.env.HOME .. "/dev/spotlight-dev-master/generate-types.sh", {
    on_exit = function(_, code)
      if code == 0 and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
end)

vim.keymap.set("n", "<leader>nc", function()
  vim.cmd("cd ~/.config/nvim")
  vim.cmd("e init.lua")
end)

vim.api.nvim_set_keymap("i", "<C-Right>", 'copilot#Accept("<CR>")', { silent = true, expr = true })

vim.keymap.set("n", "Q", function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  require('gitsigns').stage_hunk({ line, line })
end, { desc = "Stage current line" })

vim.keymap.set("v", "Q", function()
  require('gitsigns').stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { desc = "Stage selected lines" })

vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

vim.keymap.set("n", "<leader>rw", function()
  require('grug-far').toggle_instance({
    instanceName = "far",
    staticTitle = "Find and Replace",
    startInInsertMode = false,
  })
end)

vim.cmd([[
  command! W write
  command! Bd bdelete
]])
