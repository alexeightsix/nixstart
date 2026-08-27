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

    # The desktop portal. This was only turned on by desktop/flatpak.nix, as
    # part of the Flatpak stack, so on a host with `apps.flatpak = false` —
    # the laptop — nothing provided org.freedesktop.portal.Desktop at all.
    #
    # Flameshot is what makes that visible: `flameshot gui`, the Ctrl+;
    # binding in desktop/i3.nix, exits with "Could not locate the
    # `org.freedesktop.portal.Desktop` service / Unable to capture screen",
    # so the key appears to do nothing. Screen capture is not a Flatpak
    # feature, so the portal belongs here, with the session.
    #
    # flatpak.nix still sets its own `extraPortals`; both definitions merge.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "gtk";
    };

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
