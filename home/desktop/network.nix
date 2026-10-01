# Wifi, as the launcher sees it.
#
# There is no tray applet anywhere in this repository and that is deliberate:
# i3bar's tray speaks XEmbed only, while nixpkgs builds networkmanagerapplet
# with `-Dappindicator=yes`, which makes nm-applet a StatusNotifierItem and
# nothing else. It would need a snixembed shim to render at all, in a bar that
# is `mode hide` and so invisible unless $mod is held. Three moving parts to
# reach a menu the launcher can already show.
#
# So wifi is reachable three ways instead, each doing one thing:
#   - the `net` block in statusbar.nix  — which network am I on ($mod to peek)
#   - $mod+w in i3.nix                  — change network, straight to nmtui
#   - this desktop entry                — the same, found by typing in vicinae
#
# vicinae indexes `~/.nix-profile/share/applications`, which is where
# home-manager writes `xdg.desktopEntries`, so no vicinae-side configuration is
# needed — the entry appearing in its `applications` provider is the whole
# integration. `settings.Keywords` is what makes "wifi" and "network" find it
# rather than only the literal name.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
in
{
  config = lib.mkIf cfg.desktop.enable {
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
  };
}
