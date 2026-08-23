# The laptop. Same configuration, one battery.
#
# scripts/i3status-select.sh existed to tell these two apart at runtime by
# testing for /sys/class/power_supply/BAT0. This is that test, answered once.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "laptop";

  kickstart.system = {
    user.name = "alex";

    desktop.enable = true;
    apps.gui = true;

    virtualisation.docker = true;

    hardware = {
      keychron = true;
      bluetooth = true;
    };
  };

  home-manager.users.alex.kickstart.home = {
    checkout = "/home/alex/kickstart";

    user.email = "alexlatour@gmail.com";
    desktop.statusBar = "laptop";
    desktop.wallpaper = "wallpaper-2.png";

    languages = [
      "go"
      "node"
      "rust"
      "lua"
    ];
    agents = true;
  };
}
