{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.system.desktop;
in
{
  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "us";

      displayManager.lightdm.enable = lib.mkDefault true;
      # i3 itself is configured in desktop/i3.nix; this is only the session.
      windowManager.i3.enable = true;
    };

    services.displayManager.defaultSession = "none+i3";

    # xfce4-power-manager was in stage-01's package list with nothing turning
    # it on; the pieces it was standing in for are services here.
    services.upower.enable = true;
    services.libinput.enable = true;

    environment.systemPackages = with pkgs; [
      arandr
      xrandr
      xset
      xclip
      feh
      gpick
      libnotify
    ];
  };
}
