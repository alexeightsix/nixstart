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
# compilers, language servers and formatters that were coming from `dnf`,
# `npm -g`, `go install` and Mason before, none of which exist on a NixOS box
# unless something puts them there.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.kickstart.home;
  langs = cfg.languages;
  enabled = l: builtins.elem l langs;
in
{
  options.kickstart.neovim.linkConfig = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Symlink ~/.config/nvim at dotfiles/nvim in the checkout — a plain
      symlink to a writable directory, not a store path, so the tree stays
      editable and lazy.nvim can still write lazy-lock.json.

      Off by default: link it yourself once with `ln -s`, and Nix never
      touches the directory at all. Turn it on only if you want that one
      symlink kept in place for you.
    '';
  };

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

        # Providers. stage-03 ran `sudo npm install -g neovim`, which put a
        # root-owned package in a global prefix and then needed the
        # `chown -R` at the end of that stage to undo the damage.
        neovim-node-client
        python3Packages.pynvim
      ]
      # Language servers, matched to lua/config/lsp.nix's two lists. These are
      # the ones Mason was downloading; see programs.nix-ld below for why
      # Mason still works if you would rather keep it doing that.
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
      ++ lib.optionals (enabled "php") [
        intelephense
      ]
      ++ lib.optionals (enabled "lua") [
        lua-language-server
        stylua
      ];

    home.sessionVariables.EDITOR = "nvim";

    home.file.".config/nvim" = lib.mkIf config.kickstart.neovim.linkConfig {
      source = config.lib.file.mkOutOfStoreSymlink "${cfg.checkout}/dotfiles/nvim";
    };
  };
}
