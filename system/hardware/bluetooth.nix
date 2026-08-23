{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.kickstart.system.hardware.bluetooth {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
    };

    # i3config kills blueman-applet and nm-applet at startup, so the applets
    # are deliberately not autostarted here — only the tools are installed.
    environment.systemPackages = with pkgs; [
      blueman
      bluez-tools
    ];
  };
}
