# jk — vim-style keyboard scrolling for X11.
#
# i3config starts it with
#
#   exec_always --no-startup-id sh -c "pkill -x jk; exec $HOME/.local/bin/jk"
#
# and that binary is a hand-built, dynamically linked ELF looking for
# /lib64/ld-linux-x86-64.so.2 — it would not run on NixOS at all. It is a
# store path now, from jk's own flake.
#
# The pkill-then-exec dance was `exec_always` restarting it on every i3
# reload without leaving the old one holding the keyboard. A systemd user
# service does that properly: one instance, restarted on failure, stopped with
# the graphical session.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  jk = cfg.desktop.jk;

  # jk's own opted-in-by-default list, copied verbatim from `jk --help`.
  # It has to be repeated here because passing --class at all discards it —
  # "Naming any drops the default list below" — so "extra classes" is only
  # true if the defaults are handed back explicitly alongside them. Without
  # this, setting `classes` to a single entry silently stopped jk working in
  # every browser, which is the one place it works out of the box.
  browserDefaults = [
    "google-chrome"
    "chromium"
    "brave-browser"
    "vivaldi"
    "opera"
    "microsoft-edge"
    "thorium"
    "firefox"
    "librewolf"
    "waterfox"
    "floorp"
    "zen"
    "tor browser"
    "ladybird"
    "epiphany"
    "falkon"
    "konqueror"
    "midori"
  ];

  effectiveClasses = if jk.classes == [ ] then [ ] else browserDefaults ++ jk.classes;
in
{
  options.nixstart.home.desktop.jk = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Press Esc twice and j/k scroll the focused window; gg and G jump to
        the ends, Esc gives the keyboard back. On by default — it is on both
        machines, and the first Esc still reaches the application, so it
        costs nothing where it is not used.
      '';
    };

    classes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "Zathura"
        "org.gnome.Nautilus"
      ];
      description = ''
        Extra window classes to listen in, on top of jk's built-in browser
        default. Terminals and editors are deliberately not included: Esc
        already means something there.

        Additive despite jk itself replacing its default list the moment any
        --class is passed: the browsers are handed back alongside whatever is
        named here, so naming one class no longer silently disables the rest.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "rose-pine";
      description = "Overlay colours, matching the rest of the desktop.";
    };
  };

  config = lib.mkIf (cfg.desktop.enable && jk.enable) {
    systemd.user.services.jk = {
      Unit = {
        Description = "jk — keyboard scroll mode for X11";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkgs.jk)
            "--theme ${jk.theme}"
          ]
          ++ map (c: "--class ${lib.escapeShellArg c}") effectiveClasses
        );
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    home.packages = [ pkgs.jk ];
  };
}
