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
  cfg = config.kickstart.home;
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
in
{
  config = lib.mkIf desktop.enable {
    # What i3's feh line uses. Read by home/desktop/i3.nix.
    kickstart.home.desktop._resolvedWallpaper = if desktop.weather.enable then dynamic else base;

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
        ExecStart = lib.getExe pkgs.weather-wallpaper;
        Environment = [
          "WALLPAPER_INPUT=${base}"
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
