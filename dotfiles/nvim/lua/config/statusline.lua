local navic = require("nvim-navic")

-- Combined git worktree + branch component, rendered as `wt: <name> (<branch>)`.
-- The worktree name only appears inside a *linked* worktree (where `.git` is a
-- file pointing at `.../worktrees/<name>`); the branch appears whenever on a branch.
local function scm()
  local root = vim.fs.root(0, '.git')
  if not root then return '' end

  local dotgit = root .. '/.git'
  local stat = vim.uv.fs_stat(dotgit)
  local gitdir, wt
  if stat and stat.type == 'directory' then
    gitdir = dotgit
  elseif stat and stat.type == 'file' then
    local f = io.open(dotgit, 'r')
    if f then
      local line = f:read('*l') or ''
      f:close()
      gitdir = line:match('^gitdir:%s*(.-)%s*$')
      if gitdir and gitdir:sub(1, 1) ~= '/' then gitdir = root .. '/' .. gitdir end
      wt = line:match('worktrees/([^/%s]+)')
    end
  end
  if not gitdir then return '' end

  local branch
  local hf = io.open(gitdir .. '/HEAD', 'r')
  if hf then
    local head = hf:read('*l') or ''
    hf:close()
    branch = head:match('ref:%s*refs/heads/(.-)%s*$') or head:match('^(%x%x%x%x%x%x%x)')
  end

  if wt and branch then return 'wt: ' .. wt .. ' (' .. branch .. ')' end
  if wt then return 'wt: ' .. wt end
  return branch or ''
end

require('lualine').setup {
  options = {
    icons_enabled = false,
    component_separators = { left = '', right = '' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    always_show_tabline = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
      refresh_time = 16, -- ~60fps
      events = {
        'WinEnter',
        'BufEnter',
        'BufWritePost',
        'SessionLoadPost',
        'FileChangedShellPost',
        'VimResized',
        'Filetype',
        'CursorMoved',
        'CursorMovedI',
        'ModeChanged',
      },
    }
  },
  sections = {
    lualine_a = { '' },
    lualine_b = {},
    lualine_c = { 'location', 'diagnostics', {
      scm,
      cond = function() return scm() ~= '' end,
    }, { 'filename', path = 2,
      fmt = function(name)
        local git_root = vim.fs.root(0, '.git')
        if git_root then
          local buf_path = vim.fn.expand('%:p')
          if buf_path:sub(1, #git_root) == git_root then
            local root_name = vim.fn.fnamemodify(git_root, ':t')
            return root_name .. buf_path:sub(#git_root + 1)
          end
        end
        return name
      end,
    }, {
      function()
        return navic.get_location()
      end,
      cond = function()
        return navic.is_available()
      end
    },

    },
    lualine_x = {},
    lualine_y = {},
    lualine_z = { '' }
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { 'filename' },
    lualine_x = { 'location' },
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
