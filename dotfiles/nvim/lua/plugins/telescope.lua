return {
  "nvim-telescope/telescope.nvim",
  branch = "master",
  lazy = true,
  dependencies = {
    {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-live-grep-args.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make"
      }
    }
  },
  config = function()
    require("telescope").setup({
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        }
      },
      -- https://www.reddit.com/r/neovim/comments/17j970c/telescope_live_grep_doesnt_escape_special/
      -- vimgrep_arguments = table.insert(conf.vimgrep_arguments, '--fixed-strings'),
      defaults = {
        file_ignore_patterns = {
          "./database/dumps/.*.sql",
          ".git/.*",
          ".min.js",
          ".min.mjs",
          "ckeditor.jsx",
          "composer.lock",
          "lazy%-lock.json",
          "node_modules/.*",
          "package%-lock.json",
          "public/vendor/.*",
          "yarn.lock",
          "cmd/api/docs/.*",
          "schema.d.ts",
          "openapi/.*",
        },
        preview = {
          filesize_limit = 0.5555,
          mime_hook = function(filepath, bufnr, opts)
            local is_image = function(filepath)
              local image_extensions = { "png", "jpg", "gif" } -- Supported image formats
              local split_path = vim.split(filepath:lower(), ".", { plain = true })
              local extension = split_path[#split_path]
              return vim.tbl_contains(image_extensions, extension)
            end
            if is_image(filepath) then
              local term = vim.api.nvim_open_term(bufnr, {})
              local function send_output(_, data, _)
                for _, d in ipairs(data) do
                  vim.api.nvim_chan_send(term, d .. "\r\n")
                end
              end

              vim.fn.jobstart({
                "catimg",
                filepath, -- Terminal image viewer command
              }, { on_stdout = send_output, stdout_buffered = true, pty = true })
            else
              require("telescope.previewers.utils").set_preview_message(
                bufnr,
                opts.winid,
                "Binary cannot be previewed"
              )
            end
          end,
        },
      },
    })
    require('telescope').load_extension('fzf')
  end,
}
