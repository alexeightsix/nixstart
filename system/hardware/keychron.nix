# stage-09: a udev rule granting hidraw access to the Keychron K2 Pro so VIA
# can flash keyboard/keycron.layout, plus a plugdev group the script added the
# user to only if the group already happened to exist.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.nixstart.system.hardware.keychron {
    services.udev.extraRules = ''
      # Keychron K2 Pro (3434:0223) — VIA needs raw HID access
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0223", MODE="0660", GROUP="plugdev"
    '';

    users.groups.plugdev = { };
    nixstart.system.user.extraGroups = [ "plugdev" ];

    # VIA is the flashing tool the layout in keyboard/ is written for.
    environment.systemPackages = [ pkgs.via ];
  };
}
