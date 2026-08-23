# Dell XPS 13 9350 — Core Ultra 7 258V, Arc 140V, 32GB LPDDR5X, Killer BE201.
#
# scripts/i3status-select.sh existed to tell this machine and the desktop
# apart at runtime, by testing for /sys/class/power_supply/BAT0. This is that
# test, answered once, plus everything else that is only true of a laptop.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "laptop";

  kickstart.system = {
    user.name = "alex";

    desktop.enable = true;
    apps.gui = true;
    tailscale = true;

    virtualisation.docker = true;

    hardware = {
      xps13 = true; # Lunar Lake: kernel, Xe2, SOF audio, fprintd, upower
      keychron = true;
      bluetooth = true;
      # No RGB — that is the desktop's RAM.
    };
  };

  home-manager.users.alex.kickstart.home = {
    checkout = "/home/alex/kickstart";
    user.email = "alexlatour@gmail.com";

    desktop = {
      # Adds the battery block, with thresholds, and starts batsignal.
      statusBar = "laptop";
      weather.enable = true;
      weather.location = "Montreal";

      # No fixed xrandr line: this machine gets docked and undocked, so the
      # layout follows what is actually plugged in.
      autorandr = true;

      # The 9350 ships with FHD+ (1920x1200), QHD+ (2560x1600) or 2.8K OLED
      # (2880x1800) and the invoice does not say which. 1920x1200 on 13.4" is
      # ~169dpi, which is already past the point where 96 looks wrong — but
      # X's own detection is close enough there, so this stays null until the
      # panel is confirmed with `xrandr --query`.
      #
      #   FHD+  1920x1200 -> leave null
      #   QHD+  2560x1600 -> dpi = 144
      #   2.8K  2880x1800 -> dpi = 168, and GDK_SCALE kicks in
      dpi = null;
      cursorSize = 24;
    };

    languages = [
      "go"
      "node"
      "rust"
      "lua"
    ];
    agents = true;
  };
}
