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
  # The base image is 1920x1080. `feh --bg-fill` scales to *cover* the screen
  # and crops whatever overflows, so on the 1920x1200 laptop panel it scales
  # to 2133x1200 and takes 106px off each side. The temperature is drawn 30px
  # from the right edge of the image, so all but the first few pixels of it
  # land in the cropped-off strip: cut off on the laptop, fine on the 1920x1080
  # monitor, which needs no scaling at all.
  #
  # Rather than nudge the padding until it happens to survive — which only
  # holds for one panel geometry — the input is cropped to the aspect ratio of
  # the display *before* the text goes on. feh then has nothing left to crop,
  # and the text sits where the program put it on any screen.
  #
  # Geometry comes from the primary output at run time, so this follows the
  # dock: undocked it matches the panel, docked it matches the monitor and the
  # panel is off anyway (see desktop/dock.nix). If xrandr cannot be reached —
  # no X yet, no primary flagged — it falls back to the image untouched, which
  # is the behaviour before this existed.
  wallpaperFor = pkgs.writeShellApplication {
    name = "weather-wallpaper-fit";
    runtimeInputs = [
      pkgs.xrandr
      pkgs.imagemagick
      pkgs.weather-wallpaper
    ];
    text = ''
      base=${lib.escapeShellArg base}
      fitted="$(mktemp --suffix=.jpg)"
      trap 'rm -f "$fitted"' EXIT

      # "1920x1200" for the primary output, empty if anything is missing.
      geometry=$(xrandr --query 2>/dev/null \
        | awk '/ connected primary/ { if (match($0, /[0-9]+x[0-9]+\+/)) print substr($0, RSTART, RLENGTH - 1); exit }')

      if [ -n "$geometry" ]; then
        # ^ scales to cover, then a centred extent crops the overflow — the
        # same transform feh --bg-fill would have applied, done here where the
        # text has not been drawn yet.
        magick "$base" -resize "$geometry^" -gravity center -extent "$geometry" "$fitted"
        WALLPAPER_INPUT="$fitted"
      else
        WALLPAPER_INPUT="$base"
      fi
      export WALLPAPER_INPUT

      exec wallpaper
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
          # WALLPAPER_INPUT is set by the wrapper, from the cropped copy.
          "WALLPAPER_OUTPUT=${dynamic}"
          "WALLPAPER_LOCATION=${desktop.weather.location}"
        ];
      };
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
