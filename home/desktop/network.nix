# Wifi, as the launcher sees it.
#
# No tray applet, deliberately: i3bar's tray speaks XEmbed only, while
# nixpkgs builds nm-applet as a StatusNotifierItem, so it would need a
# snixembed shim. Wifi is reachable three ways instead:
#   - the `net` block in statusbar.nix  — which network am I on
#   - $mod+w in i3.nix                  — change network, straight to nmtui
#   - this desktop entry                — the same, found by typing in vicinae
#
# vicinae picks up `xdg.desktopEntries` with no configuration of its own;
# `settings.Keywords` is what makes "wifi" and "network" find it.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  xdg.desktopEntries.nmtui = {
    name = "Wi-Fi";
    genericName = "Network Connections";
    comment = "Scan for and connect to wireless networks";

    # ghostty IS the terminal here, so `terminal = false`: setting it true
    # would ask the desktop to wrap an already-wrapped command in whatever
    # it considers the default terminal.
    exec = "${lib.getExe config.programs.ghostty.package} -e ${lib.getExe' pkgs.networkmanager "nmtui"}";
    terminal = false;

    # rose-pine ships only the `-symbolic` spelling of this icon; the bare
    # `network-wireless` would fall through to adwaita rather than the theme
    # actually in use.
    icon = "network-wireless-symbolic";

    categories = [
      "Settings"
      "Network"
    ];

    settings.Keywords = "wifi;wi-fi;wireless;network;networkmanager;nmtui;connect;ssid;internet;";
  };
}
