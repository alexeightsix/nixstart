local function augroup(name)
  return vim.api.nvim_create_augroup("augroup_" .. name, { clear = true })
end

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank({
      timeout = 100
    })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup("nvim_start"),
  pattern = "*",
  nested = true,
  callback = function()
    local a = vim.fn.expand("%")

    if require('plenary').path:new(a):exists() or a == "." then
      require("telescope.builtin").oldfiles({
        only_cwd = true,
        initial_mode = "normal",
      })
    end
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = augroup("clear_message"),
  pattern = "*",
  callback = function()
    -- Clear the stale last-action message (e.g. "... written") when
    -- switching buffers so it doesn't linger in the command line.
    vim.api.nvim_echo({}, false, {})
  end,
})

function _G.statusline_func()
  if vim.b.current_func then
    return string.format(" %s:%d ", vim.b.current_func, vim.b.current_func_line or 0)
  end
  return ""
end

vim.o.statusline = "%f %{v:lua.statusline_func()} %m %r %= %y %l:%c"
