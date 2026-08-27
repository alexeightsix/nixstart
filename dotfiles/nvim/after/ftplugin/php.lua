vim.fn.setreg("t", vim.api.nvim_replace_termcodes("oeval(\\Psy\\sh());\n<ESC>", true, true, true))
