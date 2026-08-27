return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require('nvim-treesitter.configs').setup({
      ensure_installed = {
        'astro',
        'css',
        'go',
        'html',
        'php',
        'rust',
        'tsx',
        'typescript',
        'html',
      },
      auto_install = true,
      highlight = {
        enable = true
      }
    })
  end
}
