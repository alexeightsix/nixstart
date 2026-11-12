# The `nixstart.home.*` namespace. system/home.nix sets these from
# `nixstart.system.*`; the home layer never reads the system layer.
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

    # The dotfiles, in their two forms: a store path Nix reads (pinned, frozen
    # until the next rebuild) and a checkout read at runtime (editable).

    dotfiles = mkOption {
      type = types.path;
      description = ''
        Store path of dotfiles/ in this repository. Read at build time:
        tmux.conf, dunstrc, the Ghostty shaders and the wallpapers.
      '';
    };

    checkout = mkOption {
      type = types.str;
      default = "/home/alex/nixstart";
      description = ''
        Working checkout of this repository, referred to by path and never
        read. dotfiles/nvim and dotfiles/pi are linked from here so an edit
        takes effect on save rather than on `nixos-rebuild`.
      '';
    };

    wallpapers = mkOption {
      type = types.path;
      description = "Store path of wallpapers/ in this repository.";
    };

    desktop = {
      hibernateAfter = mkOption {
        type = types.nullOr types.ints.positive;
        default = 30;
        description = ''
          Minutes of X idle time before the machine hibernates, implemented by
          home/desktop/idle.nix. The lock that happens first is X's own
          screensaver timer driving xss-lock, and is separate from this.
          null leaves the session locked but awake indefinitely.
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
          Fragment shader Ghostty runs over the terminal, from
          dotfiles/ghostty-shaders/. null turns the shader off.
        '';
      };

      wallpaper = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "wallpaper-3.png";
        description = ''
          Filename under wallpapers/. null means the last one by name, so
          adding a new wallpaper is all it takes to switch to it.
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
            on a schedule.
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
            How often to redraw. The temperature changes a few times a day;
            every minute would be pointless load on a free API.
          '';
        };

        textColor = mkOption {
          type = types.str;
          default = "white";
          example = "#2b1410";
          description = ''
            Colour of the temperature, as #RRGGBB, #RGB, "white" or "black".
            Which colour is legible depends on the wallpaper, so it is set
            alongside it.
          '';
        };

        shadowColor = mkOption {
          type = types.str;
          default = "black";
          example = "#f8e4c8";
          description = ''
            Colour of the shadow behind the temperature, same formats as
            textColor. Drawn two pixels down and right, so on a pale image it
            wants to be the light half of the pair rather than the dark one.
          '';
        };
      };

      pairedWorkspaces = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Switch every screen at once: $mod+N puts the primary output on
          workspace N and the other screen on N + 10 (named "11:1" through
          "20:10", which the bar renders as 1-10). Assigned to
          `primary`/`nonprimary`, so it follows the dock; undocked it is an
          ordinary single-screen switch. $mod+Shift+N sends the window to the
          half of the pair on the screen you are on.
        '';
      };

      barOutputs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "primary" ];
        description = ''
          Outputs i3bar is drawn on, as `bar { output ... }` names; empty
          means every output. "primary" follows the X primary flag, which
          `dock` sets, so the bar moves with the dock. Without something
          setting a primary, "primary" matches nothing and there is no bar.
        '';
      };

      monitors = mkOption {
        type = types.lines;
        default = "";
        example = "xrandr --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate normal";
        description = ''
          Fixed xrandr layout, run at i3 start. Leave empty when `dock` or
          `autorandr` manages the layout.
        '';
      };

      autorandr = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Apply a saved autorandr profile on login and on hotplug. Save one
          with `autorandr --save docked`; with none saved this does nothing,
          which is why `dock` exists.
        '';
      };

      dock = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Follow the external monitor: when one is connected, use it and
            switch the internal panel off; when the last one is unplugged,
            switch the panel back on. Applied at login and on every hotplug.
            Unlike autorandr it needs no saved profile, so it works on a
            monitor it has never seen; a saved autorandr profile still wins.
          '';
        };

        internal = mkOption {
          type = types.str;
          default = "eDP-1";
          example = "LVDS-1";
          description = ''
            The built-in panel — the output that gets switched off while an
            external monitor is connected. `xrandr --query` names it.
          '';
        };

        keepInternal = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Keep the internal panel on when docked, extending onto it rather
            than switching it off, positioned per `internalPosition`.
          '';
        };

        internalPosition = mkOption {
          type = types.enum [
            "left-of"
            "right-of"
            "below"
          ];
          default = "right-of";
          description = ''
            Where the built-in panel sits physically relative to the external
            monitor, when `keepInternal` is true. `below` is centred, computed
            as an explicit `--pos` since xrandr's `--below` left-aligns — see
            home/desktop/dock.nix.
          '';
        };

        internalMode = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "1680x1050";
          description = ''
            Force a mode on the built-in panel instead of `--auto` (null).
            Enlarges text on the panel alone, which `dpi` cannot since
            Xft.dpi is global. Must be listed by `xrandr --query` and should
            keep the panel's aspect ratio.
          '';
        };
      };

      dpi = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 144;
        description = ''
          X server DPI (Xft.dpi), for a HiDPI panel. null leaves X to its own
          detection, which is right at 1920x1200.
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
          "python"
          "rust"
          "lua"
          "android"
        ]
      );
      default = [ ];
      description = ''
        Toolchains, and the language servers and formatters Neovim's config
        expects to find on PATH. The editor configuration itself is not
        managed here — see home/editor/neovim.nix.

        `android` is the Android SDK, a JDK 17 and Gradle. See
        pkgs/android-sdk for what the versions are pinned to and why.
      '';
    };

    databases = mkOption {
      type = types.bool;
      default = false;
      description = ''
        mariadb and postgresql clients. The servers run in Docker.
      '';
    };

    agents = mkOption {
      type = types.bool;
      default = false;
      description = "Coding agents: claude-code, codex, opencode, pi.";
    };
  };
}
