# Neovim — installed, not managed.
#
# This module deliberately does not use `programs.neovim`, does not generate an
# init.lua, and does not write to ~/.config/nvim. dotfiles/nvim stays exactly
# what it is: a lazy.nvim tree with its own lazy-lock.json, edited in place and
# reloaded without a rebuild. Putting it in the store would make every plugin
# change a `nixos-rebuild`, and lazy.nvim cannot write its lockfile to a
# read-only path anyway.
#
# What Nix is responsible for here is the *environment* Neovim runs in — the
# compilers, language servers and formatters its config expects on PATH.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.nixstart.home;
  langs = cfg.languages;
  enabled = l: builtins.elem l langs;
in
{
  config = {
    # The editor and the things its config shells out to. init.lua is
    # untouched.
    home.packages =
      with pkgs;
      [
        neovim

        # treesitter compiles parsers on :TSUpdate, telescope/fd/rg back the
        # pickers, and `make` is needed by a couple of plugins' build steps.
        gcc
        gnumake
        cmake
        git
        curl
        unzip
        ripgrep
        fd

        # Providers.
        neovim-node-client
        python3Packages.pynvim
      ]
      # Language servers, matched to lua/config/lsp.lua's two lists. Mason
      # still works too; see system/core/nix-ld.nix.
      ++ lib.optionals (enabled "node") [
        typescript-language-server
        vscode-langservers-extracted # cssls, eslint, html, json
        tailwindcss-language-server
        dockerfile-language-server
        docker-compose-language-service
        prettierd
      ]
      ++ lib.optionals (enabled "go") [
        gopls
        templ
        golangci-lint
      ]
      ++ lib.optionals (enabled "lua") [
        lua-language-server
        stylua
      ];

    home.sessionVariables.EDITOR = "nvim";

    home.file.".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${cfg.checkout}/dotfiles/nvim";
    };
  };
}
