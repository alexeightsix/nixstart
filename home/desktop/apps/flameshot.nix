# Screenshots.
#
# flameshot rewrites flameshot.ini from its own UI, so the file is seeded once
# and then left alone; see home/lib.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  helpers = import ../../lib.nix { inherit lib config; };

  # useX11LegacyScreenshot below is what makes ctrl+; work at all: flameshot 14
  # captures through the XDG screenshot portal, and no backend in nixpkgs
  # implements Screenshot for plain X11, so every capture timed out after 30s.
  # See https://wiki.nixos.org/wiki/Flameshot.
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
    useX11LegacyScreenshot=true
  '';
in
{
  home.packages = [ pkgs.flameshot ];

  # savePath points here, and flameshot does not create it: with the
  # directory missing a capture is taken and then silently fails to save.
  home.file."Pictures/.keep".text = "";

  # checkForUpdates is off: the version is pinned by the lockfile.
  home.activation.seedFlameshot = helpers.mkSeededFile {
    target = "${config.xdg.configHome}/flameshot/flameshot.ini";
    source = ini;
  };
}
