# The `kickstart.home.*` namespace — what a person carries between machines.
#
# This module set is deliberately independent of the NixOS one. It evaluates
# with nothing but home-manager, so `home-manager switch --flake .#alex@headless`
# configures an account on a machine this repository does not own — the Fedora
# desktop during the migration, a dev box, an Incus instance. That was the job
# `link.sh --headless` was doing, and the reason its list had already drifted
# from stage-03's was that the two were maintained separately.
#
# When NixOS *is* in charge, system/home.nix sets these from
# `kickstart.system.*`. The direction is one-way and explicit: the system
# layer knows about the home layer, never the reverse.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.kickstart.home = {

    user = {
      name = mkOption {
        type = types.str;
        default = "alex";
        description = "Account name.";
      };
      fullName = mkOption {
        type = types.str;
        default = "Alexander Latour";
        description = "Name recorded in git commits.";
      };
      email = mkOption {
        type = types.str;
        default = "alexlatour@gmail.com";
        description = "Email recorded in git commits.";
      };
    };

    # The dotfiles repository, in its two forms.
    #
    # The distinction is the one thing this port has to get right. A file Nix
    # reads is pinned and reproducible but frozen until the next rebuild; a
    # file read at runtime is editable but outside Nix's knowledge. Both are
    # correct for different files, and conflating them is what makes ported
    # configurations feel worse than the shell scripts they replaced.

    dotfiles = mkOption {
      type = types.path;
      description = ''
        Store path of the dotfiles checkout, from the `dotfiles` flake input.
        Read at build time: tmux.conf, the zellij config and layouts, the
        alias files, copyline, the wallpapers.
      '';
    };

    checkout = mkOption {
      type = types.str;
      default = "/home/alex/kickstart";
      description = ''
        Working checkout on the machine, referred to by path and never read.
        This is where the trees that are edited far more often than the system
        is rebuilt live — dotfiles/nvim and dotfiles/pi — so that an edit
        takes effect on save rather than on `nixos-rebuild`.
      '';
    };

    wallpapers = mkOption {
      type = types.path;
      description = "Store path of the wallpapers directory, from the dotfiles input.";
    };

    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "i3, the bar, the compositor, notifications, the terminal.";
      };

      statusBar = mkOption {
        type = types.enum [
          "laptop"
          "desktop"
        ];
        default = "desktop";
        description = ''
          Which i3status-rust configuration the bar runs.
          scripts/i3status-select.sh decided this at runtime by looking for
          /sys/class/power_supply/BAT0. A host knows which it is at build
          time, so it says so.
        '';
      };

      wallpaper = mkOption {
        type = types.str;
        default = "wallpaper-2.png";
        description = "Filename under the dotfiles checkout's wallpapers/.";
      };

      monitors = mkOption {
        type = types.lines;
        default = "";
        example = "xrandr --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate normal";
        description = ''
          Per-host xrandr layout, run at i3 start. scripts/xrandr.sh was a
          single commented-out line, so every machine ran an empty script.
        '';
      };
    };

    languages = mkOption {
      type = types.listOf (
        types.enum [
          "go"
          "node"
          "php"
          "python"
          "rust"
          "lua"
        ]
      );
      default = [ ];
      description = ''
        Toolchains, and the language servers and formatters Neovim's config
        expects to find on PATH. The editor configuration itself is not
        managed here — see home/editor/neovim.nix.
      '';
    };

    agents = mkOption {
      type = types.bool;
      default = false;
      description = "Coding agents: claude-code, codex, opencode, pi.";
    };
  };
}
