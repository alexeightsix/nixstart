# Screenshots.
#
# flameshot rewrites flameshot.ini as you change settings in its own UI, which
# is why link.sh `render`ed it instead of linking — a symlink would send those
# writes back into the repository. A store path is read-only, so it would make
# the write fail instead. The file is seeded once and then left alone; see
# home/lib.nix.
#
# savePath was the literal /home/alex/Pictures. It follows the account now.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  helpers = import ../lib.nix { inherit lib config; };

  ini = pkgs.writeText "flameshot.ini" ''
    [General]
    autoCloseIdleDaemon=true
    buttons=@Variant(\0\0\0\x7f\0\0\0\vQList<int>\0\0\0\0\x14\0\0\0\0\0\0\0\x1\0\0\0\x2\0\0\0\x3\0\0\0\x4\0\0\0\x5\0\0\0\x6\0\0\0\x12\0\0\0\xf\0\0\0\x16\0\0\0\x13\0\0\0\b\0\0\0\t\0\0\0\x10\0\0\0\n\0\0\0\v\0\0\0\x17\0\0\0\xe\0\0\0\f\0\0\0\x11)
    checkForUpdates=false
    contrastOpacity=188
    contrastUiColor=#191724
    disabledTrayIcon=true
    drawColor=#ebbcba
    drawThickness=2
    saveAfterCopy=true
    savePath=${config.home.homeDirectory}/Pictures
    showAbortNotification=false
    showDesktopNotification=false
    showHelp=false
    showSelectionGeometry=5
    showSidePanelButton=false
    showStartupLaunchMessage=false
    startupLaunch=true
    uiColor=#eb6f92
    uiLanguage=auto
  '';
in
{
  config = lib.mkIf cfg.desktop.enable {
    home.packages = [ pkgs.flameshot ];

    # savePath points here, and flameshot does not create it: with the
    # directory missing a capture is taken and then silently fails to save.
    # link.sh never made it either — it existed on the old machine because
    # something else had happened to create it.
    home.file."Pictures/.keep".text = "";

    # checkForUpdates and ignoreUpdateToVersion=14.0.0 were in the tracked
    # file; an update check is meaningless when the version is pinned by the
    # lockfile, so it is off.
    home.activation.seedFlameshot = helpers.mkSeededFile {
      target = "${config.xdg.configHome}/flameshot/flameshot.ini";
      source = ini;
    };
  };
}
