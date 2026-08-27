return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-nvim-lsp-signature-help",
  },
  config = function()
    local cmp = require("cmp")

    local has_words_before = function()
      unpack = unpack or table.unpack
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
    end

    cmp.setup({
      sorting = {
        priority_weight = 2,
        comparators = {
          -- Custom comparator: field > function
          function(entry1, entry2)
            local kind1 = entry1:get_kind() or 0
            local kind2 = entry2:get_kind() or 0

            local lsp = require('vim.lsp.protocol')
            -- Define priorities: lower number = higher priority
            local priority = {
              [lsp.CompletionItemKind.Field] = 1,
              [lsp.CompletionItemKind.Property] = 1,
              [lsp.CompletionItemKind.Function] = 2,
              [lsp.CompletionItemKind.Method] = 2,
            }

            local p1 = priority[kind1] or 99
            local p2 = priority[kind2] or 99

            if p1 < p2 then
              return true
            elseif p1 > p2 then
              return false
            end
          end,

          -- Keep the default ones after
          cmp.config.compare.offset,
          cmp.config.compare.exact,
          cmp.config.compare.score,
          cmp.config.compare.recently_used,
          cmp.config.compare.locality,
          cmp.config.compare.kind,
          cmp.config.compare.sort_text,
          cmp.config.compare.length,
          cmp.config.compare.order,
        },
      },
      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-Up>"] = function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end,
        ["<C-Down>"] = function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end,
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
      }),
      sources = {
        { name = "nvim_lsp" },
        { name = "path" },
        { name = "buffer" },
        { name = "nvim_lsp_signature_help" },
      },
    })
  end
}
