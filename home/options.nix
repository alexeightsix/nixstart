# The `nixstart.home.*` namespace — what a person carries between machines.
#
# This module set is deliberately independent of the NixOS one. It evaluates
# with nothing but home-manager, so `home-manager switch --flake .#alex@headless`
# configures an account on a machine this repository does not own — the Fedora
# desktop during the migration, a dev box, an Incus instance. That was the job
# `link.sh --headless` was doing, and the reason its list had already drifted
# from stage-03's was that the two were maintained separately.
#
# When NixOS *is* in charge, system/home.nix sets these from
# `nixstart.system.*`. The direction is one-way and explicit: the system
# layer knows about the home layer, never the reverse.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.nixstart.home = {

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
        Read at build time: tmux.conf, dunstrc, the Ghostty shaders and the
        wallpapers.
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

      ghosttyShader = mkOption {
        type = types.nullOr (
          types.enum [
            "bloom"
            "water"
          ]
        );
        default = "bloom";
        description = ''
          Fragment shader Ghostty runs over the terminal, from the dotfiles
          checkout's ghostty-shaders/. The tracked ghostty config named
          bloom.glsl but the file itself was never in the repository — it
          existed only in ~/.config on the one machine, so Ghostty logged a
          warning and carried on anywhere else. null turns the shader off.
        '';
      };

      wallpaper = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "wallpaper-3.png";
        description = ''
          Filename under wallpapers/. null means the last one, by name — so
          adding wallpaper-6 to the repository is all it takes to switch to
          it, and nothing has to be edited here.
        '';
      };

      # Resolved by home/desktop/wallpaper.nix: the static image, or the
      # dynamic one when the weather wallpaper is on. Internal.
      _resolvedWallpaper = mkOption {
        type = types.str;
        internal = true;
        default = "";
      };

      weather = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Redraw the wallpaper with the current temperature in the corner,
            on a schedule. Replaces the two crontab lines that were doing this
            — one every minute, and an @reboot entry that polled `xset q` up
            to 150 times waiting for an X server to exist.
          '';
        };

        location = mkOption {
          type = types.str;
          default = "Montreal";
          description = "Location name, geocoded through Open-Meteo.";
        };

        interval = mkOption {
          type = types.str;
          default = "15m";
          description = ''
            How often to redraw. The crontab ran this every minute, which is
            sixty geocode-plus-forecast round trips an hour against a free API
            to render a number that changes a few times a day.
          '';
        };
      };

      monitors = mkOption {
        type = types.lines;
        default = "";
        example = "xrandr --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate normal";
        description = ''
          Per-host xrandr layout, run at i3 start. scripts/xrandr.sh was a
          single commented-out line, so every machine ran an empty script.

          Leave empty on a laptop and let autorandr handle it instead — see
          `autorandr` below, which reacts to a monitor being plugged in
          rather than running once at login.
        '';
      };

      autorandr = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Detect the connected outputs and apply a saved profile, on login
          and whenever one is plugged or unplugged. A fixed xrandr line is
          fine on a machine whose monitors never change; a laptop that is
          docked and undocked wants this.

          Save a layout once it looks right: `autorandr --save docked`.
        '';
      };

      dpi = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 144;
        description = ''
          X server DPI, for a HiDPI panel. i3, dmenu and anything else drawing
          through Xft read this; without it a 2880x1800 13" panel renders at
          96dpi and everything is about half the size it should be.

          null leaves X to its own detection, which is right at 1920x1200.
        '';
      };

      cursorSize = mkOption {
        type = types.int;
        default = 24;
        description = "X cursor size; scale with dpi on a HiDPI panel.";
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
          "gtk"
        ]
      );
      default = [ ];
      description = ''
        Toolchains, and the language servers and formatters Neovim's config
        expects to find on PATH. The editor configuration itself is not
        managed here — see home/editor/neovim.nix.
      '';
    };

    databases = mkOption {
      type = types.bool;
      default = false;
      description = ''
        mariadb and postgresql clients. stage-01 installed both server
        packages to get the `mysql` and `psql` binaries; the servers
        themselves run in Docker, so only the clients are here.
      '';
    };

    agents = mkOption {
      type = types.bool;
      default = false;
      description = "Coding agents: claude-code, codex, opencode, pi.";
    };
  };
}
