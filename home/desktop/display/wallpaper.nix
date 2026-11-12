# The wallpaper, static and dynamic.
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

  # feh --bg-fill crops the image differently on each differently-shaped
  # screen, which cut the temperature off on the panel. So the image is laid
  # out for the whole root window instead: each monitor's rectangle gets its
  # own scale-to-cover crop, feh runs with --no-xinerama, and the generator
  # draws the temperature once per monitor. Geometry is read at run time; if
  # xrandr cannot be read it falls back to the base image and plain --bg-fill.
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
      # note in desktop/display/dock.nix) and would otherwise be drawn for.
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

      # magick unconditionally, even in the fallback. It used to be that the
      # generator decoded JPEG only, so a .png in assets/wallpapers/ failed at the
      # decode unless it came through here first; robustness.patch moved that
      # to image.Decode and the format no longer matters. What keeps this
      # unconditional is the canvas itself — WALLPAPER_INPUT is a path, so
      # there has to be a file to point at either way, and going through
      # magick on both paths keeps the two branches differing only in layout.
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

  # The layout is an input to the image, so a layout change redraws it.
  # Keyed on the layout rather than the event: the first drm event arrives
  # before dock.nix has applied the new layout and is ignored; applying it
  # emits another, which this acts on.
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
  # What i3's feh line uses. Read by home/desktop/wm/i3.nix.
  #
  # Always the base image, even with the weather wallpaper on: it is a store
  # path and always exists, while the dynamic one may not yet. The weather
  # run calls feh itself and replaces it a few seconds later.
  nixstart.home.desktop._resolvedWallpaper = base;

  systemd.user.services.weather-wallpaper = lib.mkIf desktop.weather.enable {
    Unit = {
      Description = "Draw the current temperature onto the wallpaper";
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

        # Legibility depends on the base image, so the colours are set with
        # the wallpaper. Parsed by pkgs/weather-wallpaper/robustness.patch.
        "WALLPAPER_TEXT_COLOR=${desktop.weather.textColor}"
        "WALLPAPER_SHADOW_COLOR=${desktop.weather.shadowColor}"
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
}
