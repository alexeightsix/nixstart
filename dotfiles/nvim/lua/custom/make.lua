local M = {}

-- Parse target names from a Makefile, skipping dot targets (.PHONY etc.),
-- pattern rules, and duplicates.
function M.targets(path)
  local targets = {}
  local seen = {}
  for _, line in ipairs(vim.fn.readfile(path)) do
    local target = line:match("^([%a%d_%-%.]+)%s*:")
    if target and not target:find("%%") and target:sub(1, 1) ~= "." and not seen[target] then
      seen[target] = true
      table.insert(targets, target)
    end
  end
  return targets
end

-- Run `make <target>` in a terminal split, closing it on a clean (0) exit.
function M.run(target)
  vim.cmd("new")
  local win = vim.api.nvim_get_current_win()
  vim.fn.termopen("make " .. target, {
    on_exit = function(_, code)
      if code == 0 and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
  vim.cmd("startinsert")
end

-- Open a Telescope picker of the project's Makefile targets and run the
-- selected one.
function M.pick()
  local path = vim.fn.filereadable("Makefile") == 1 and "Makefile"
    or (vim.fn.filereadable("makefile") == 1 and "makefile")

  if not path then
    vim.notify("No Makefile found", vim.log.levels.WARN)
    return
  end

  local targets = M.targets(path)

  if #targets == 0 then
    vim.notify("No targets found in " .. path, vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Make Targets",
    finder = finders.new_table({ results = targets }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          M.run(selection[1])
        end
      end)
      return true
    end,
  }):find()
end

return M
