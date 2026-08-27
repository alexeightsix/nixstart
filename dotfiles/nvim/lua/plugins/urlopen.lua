return {
  "sontungexpt/url-open",
  branch = "mini",
  event = "VeryLazy",
  cmd = "URLOpenUnderCursor",
  config = function()
    local status_ok, _ = pcall(require, "url-open")
    if not status_ok then
      return
    end
    require("url-open").setup({
      open_app = "default",
      open_only_when_cursor_on_url = false,
      highlight_url = {
        all_urls = {
          enabled = false,
          fg = "#ffb86c",       -- "text" or "#rrggbb"
          bg = nil,             -- nil or "#rrggbb"
          underline = true,
        },
        cursor_move = {
          enabled = true,
          fg = "#ffb86c",       -- "text" or "#rrggbb"
          bg = nil,             -- nil or "#rrggbb"
          underline = true,
        },
      },
      deep_pattern = false,
    })
  end
}
