vim.fn.setreg("e", vim.api.nvim_replace_termcodes("iif err != nil {\n  return err \n }\n \n", true, true, true))
