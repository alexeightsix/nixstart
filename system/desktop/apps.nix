# The graphical applications, whatever channel Fedora happened to get them
# from: dnf (stage-01), a downloaded rpm (Chrome), a vendor repo (Beekeeper,
# stage-12) or Flathub (stage-04). One list now.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.system;
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.apps.gui) {
    environment.systemPackages = with pkgs; [
      # browsers
      firefox
      google-chrome

      # chat and meetings — were Flatpaks, with /usr/bin symlinks after them
      slack
      discord
      zoom-us
      telegram-desktop

      # notes, api, db
      obsidian
      postman
      beekeeper-studio
      transmission_4

      # media and images
      vlc
      gimp

      # system
      btop
      fastfetch
      ncdu
      gnome-system-monitor
      gnome-tweaks
      gparted
      filezilla
      cameractrls
      piper # the Logitech mouse configurator, with its ratbagd below
    ];

    services.ratbagd.enable = true;
    programs.dconf.enable = true;
  };
}
