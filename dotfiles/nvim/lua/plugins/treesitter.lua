-- Pinned to master.
--
-- nvim-treesitter's default branch is now `main`, a rewrite that deleted the
-- `nvim-treesitter.configs` module this config is written against — hence
--
--   Failed to run `config` for nvim-treesitter
--   module 'nvim-treesitter.configs' not found
--
-- on a fresh install, where lazy.nvim clones whatever upstream's default
-- branch happens to be. master is still maintained and still has the
-- ensure_installed / auto_install / highlight options below; `main` replaces
-- them with require('nvim-treesitter').install{} plus vim.treesitter.start()
-- in a FileType autocommand, which is a rewrite of this file rather than a
-- rename. Pinning is the smaller, reversible move.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
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
