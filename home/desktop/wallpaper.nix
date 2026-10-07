# The wallpaper, static and dynamic.
#
# i3config had `feh --bg-fill $HOME/kickstart/wallpapers/wallpaper-2.png`
# hardcoded, while ~/.fehbg — what actually ran — pointed at
# ~/.cache/wallpaper-dynamic.jpg, the output of a Go program in a checkout
# under ~/dev/archive driven by two crontab lines. So the tracked config and
# the running system had disagreed about the wallpaper for some time.
#
# Both halves are here now, and i3 sets whichever one is actually in use.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  desktop = cfg.desktop;

  # "The last one, by name." wallpaper-4.jpg and wallpaper-5.jpg break a plain
  # sort against wallpaper-10.png, so the numeric part is compared as a number.
  wallpapers = builtins.attrNames (builtins.readDir cfg.wallpapers);
  indexOf =
    name:
    let
      m = builtins.match "wallpaper-([0-9]+)\\..*" name;
    in
    if m == null then -1 else lib.toInt (builtins.head m);
  latest = builtins.head (
    lib.sort (a: b: indexOf a > indexOf b) (builtins.filter (n: indexOf n >= 0) wallpapers)
  );

  chosen = if desktop.wallpaper == null then latest else desktop.wallpaper;
  base = "${cfg.wallpapers}/${chosen}";

  dynamic = "${config.home.homeDirectory}/.cache/wallpaper-dynamic.jpg";

  # The base image is 1920x1080 and the root window usually is not. `feh
  # --bg-fill` scales to *cover* and crops the overflow, and with Xinerama it
  # does that once per screen, so the crop is a different crop on every screen
  # that is not the base image's shape. On the 1680x1050 panel it scales to
  # 1867x1050 and takes 93px off each side; the temperature is drawn 30px from
  # the right edge, so nearly all of it lands in the strip that gets thrown
  # away — cut off on the panel, fine on the 1920x1080 monitor, which needs no
  # scaling at all. Docked, with the panel kept on (see desktop/dock.nix),
  # that is both screens disagreeing about the same image at once.
  #
  # An earlier attempt cropped the input to the geometry of the *primary*
  # output before the text went on. That fixes whichever screen happens to be
  # primary and leaves the other one exactly as wrong as before, because there
  # is no single aspect ratio that suits two differently-shaped screens.
  #
  # So the image stops being one screen's wallpaper and becomes the whole root
  # window's: a canvas the size of the X screen, with each monitor's rectangle
  # filled by its own scale-to-cover crop of the base image. feh then has
  # nothing left to crop — it is told so with --no-xinerama — and the
  # generator draws the temperature once per monitor rectangle rather than once
  # in the corner of the image. Every screen gets an uncropped corner, whatever
  # its resolution.
  #
  # Geometry is read at run time, so this follows the dock rather than assuming
  # a layout. If xrandr cannot be reached — no X yet, or a layout it cannot
  # parse — it falls back to the base image with one corner and plain
  # --bg-fill, which is the single-screen behaviour.
  wallpaperFor = pkgs.writeShellApplication {
    name = "weather-wallpaper-fit";
    runtimeInputs = [
      pkgs.coreutils # mktemp
      pkgs.xrandr
      pkgs.gawk
      pkgs.imagemagick
      pkgs.weather-wallpaper
    ];
    text = ''
      base=${lib.escapeShellArg base}
      canvas="$(mktemp --suffix=.jpg)"
      trap 'rm -f "$canvas"' EXIT

      # `xrandr --listmonitors` rather than `--query`: it reports one line per
      # *active* monitor and nothing for an output that is connected but
      # switched off, which is the distinction that matters here. A disabled
      # panel keeps its old modeline in --query output (see the stale-CRTC
      # note in desktop/dock.nix) and would otherwise be drawn for.
      #
      #    Monitors: 2
      #     0: +*DP-1 1920/600x1080/340+0+0  DP-1
      #     1: +eDP-1 1680/288x1050/180+120+1080  eDP-1
      #
      # Field 3 is the geometry with the physical size in millimetres welded
      # into it after each slash; dropping those leaves "1920x1080+0+0".
      layout=$(xrandr --listmonitors 2>/dev/null) || layout=""
      mapfile -t monitors < <(
        printf '%s\n' "$layout" \
          | awk 'NR > 1 && $3 ~ /^[0-9]+\/[0-9]+x[0-9]+\/[0-9]+\+[0-9]+\+[0-9]+$/ {
                   gsub(/\/[0-9]+/, "", $3); print $3
                 }'
      )

      # The root window, which is what feh paints and is not the bounding box
      # of the monitors whenever panning or a rotated output is involved.
      #
      #   Screen 0: minimum 320 x 200, current 1920 x 2130, maximum 16384 x 16384
      screen=$(xrandr --query 2>/dev/null \
        | awk '/^Screen/ {
                 if (match($0, /current [0-9]+ x [0-9]+/)) {
                   s = substr($0, RSTART + 8, RLENGTH - 8); gsub(/ /, "", s); print s
                 }
                 exit
               }') || screen=""

      # magick unconditionally, even in the fallback: the generator decodes
      # JPEG only, and the base image is whichever file wallpapers/ holds —
      # a .png there would otherwise fail at the decode.
      if [ "''${#monitors[@]}" -gt 0 ] && [ -n "$screen" ]; then
        # One scale-to-cover crop of the base per monitor, composited at that
        # monitor's offset. `-resize WxH^` covers rather than fits and
        # `-extent` with a centred gravity trims what covering overshot —
        # the same transform feh --bg-fill would have applied, done here,
        # per screen, while there is still no text to lose.
        #
        # `-gravity none` after the parentheses is load-bearing. -gravity is
        # a setting rather than an operator and the parentheses do not scope
        # it, so the `center` the -extent above needs is still in force when
        # -composite reads it — and -composite with a gravity treats
        # -geometry as an offset *from that gravity's anchor* rather than
        # from the origin. Left set, every tile lands centred on the canvas:
        # the 1920x1080 monitor at y=525 instead of y=0.
        compose=(-size "$screen" xc:black)
        for monitor in "''${monitors[@]}"; do
          geometry=''${monitor%%+*}
          offset=''${monitor#"$geometry"}
          compose+=(
            \( "$base" -resize "''${geometry}^" -gravity center -extent "$geometry" \)
            -gravity none -geometry "$offset" -composite
          )
        done
        magick "''${compose[@]}" "$canvas"

        monitor_list=$(printf '%s,' "''${monitors[@]}")
        export WALLPAPER_MONITORS="''${monitor_list%,}"
      else
        magick "$base" "$canvas"
      fi

      export WALLPAPER_INPUT="$canvas"

      exec wallpaper
    '';
  };

  # The layout is an input to the image now, so a change of layout has to
  # redraw it. Without this, docking or undocking leaves a wallpaper laid out
  # for the previous arrangement until the timer next fires — up to `interval`
  # of exactly the cut-off text the canvas above exists to prevent.
  #
  # Same mechanism as desktop/dock.nix's watcher, and separate from it on
  # purpose: that one only exists when `dock.enable` is set, and this has to
  # work regardless. The guard is the layout itself rather than the event,
  # which is what resolves the race between the two — a drm event arrives
  # before dock.nix has applied the new layout, so the first look still sees
  # the old one and does nothing; applying it emits another event, and that is
  # the one this acts on. It also absorbs the DPMS and mode-set events that
  # change no geometry at all.
  layoutWatch = pkgs.writeShellApplication {
    name = "weather-wallpaper-watch";
    runtimeInputs = [
      pkgs.coreutils # sleep
      pkgs.xrandr
      pkgs.systemd
    ];
    text = ''
      signature() {
        xrandr --listmonitors 2>/dev/null || true
      }

      last=$(signature)

      udevadm monitor --udev --subsystem-match=drm | while read -r _; do
        # The event beats the mode change it announces; xrandr is only worth
        # asking once the new layout has actually landed.
        sleep 1

        current=$(signature)
        if [ "$current" = "$last" ]; then
          continue
        fi
        last=$current

        systemctl --user start --no-block weather-wallpaper.service || true
      done
    '';
  };
in
{
  config = lib.mkIf desktop.enable {
    # What i3's feh line uses. Read by home/desktop/i3.nix.
    #
    # Always the base image, even when the weather wallpaper is on, and that
    # is deliberate. This used to resolve to `dynamic`, which is a path in
    # ~/.cache that nothing guarantees exists: the timer first fires 30s into
    # the session, so a fresh login had no wallpaper until it did, and a
    # single failing run left the desktop bare indefinitely. That is exactly
    # what happened — see the font patch in pkgs/weather-wallpaper.
    #
    # The base image is a store path, so it is always there. i3 draws it
    # immediately at login and the weather run — which calls feh itself once
    # it has written the file — replaces it a few seconds later. The failure
    # mode of the weather half is now a wallpaper without a temperature on
    # it, rather than no wallpaper.
    nixstart.home.desktop._resolvedWallpaper = base;

    systemd.user.services.weather-wallpaper = lib.mkIf desktop.weather.enable {
      Unit = {
        Description = "Draw the current temperature onto the wallpaper";
        # The @reboot crontab line polled `xset q` in a loop because cron has
        # no idea whether X is up. systemd does.
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe wallpaperFor;
        Environment = [
          # WALLPAPER_INPUT and WALLPAPER_MONITORS are set by the wrapper,
          # from the canvas it lays out for the screens that are actually on.
          "WALLPAPER_OUTPUT=${dynamic}"
          "WALLPAPER_LOCATION=${desktop.weather.location}"
        ];
      };
    };

    # Redraw when the screens change, not only when the timer comes round.
    systemd.user.services.weather-wallpaper-watch = lib.mkIf desktop.weather.enable {
      Unit = {
        Description = "Redraw the weather wallpaper when the display layout changes";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # `udevadm monitor` never exits, so this is the long-running half.
        ExecStart = lib.getExe layoutWatch;
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.timers.weather-wallpaper = lib.mkIf desktop.weather.enable {
      Unit.Description = "Refresh the weather wallpaper";
      Timer = {
        OnStartupSec = "30s";
        OnUnitActiveSec = desktop.weather.interval;
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    home.packages = lib.optional desktop.weather.enable pkgs.weather-wallpaper ++ [ pkgs.feh ];
  };
}
