return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      blade = {
        "blade-formatter",
      },
      lua = {
        "stylua"
      },
      javascript = {
        "prettierd",
        "prettier",
        stop_after_first = true
      },
    }
  }
}
