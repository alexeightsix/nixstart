# hidraw access to the Keychron K2 Pro so VIA can flash its layout.
{
  pkgs,
  ...
}:
{
  services.udev.extraRules = ''
    # Keychron K2 Pro (3434:0223) — VIA needs raw HID access
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0223", MODE="0660", GROUP="plugdev"
  '';

  users.groups.plugdev = { };
  nixstart.system.user.extraGroups = [ "plugdev" ];

  # VIA is the flashing tool the layout in keyboard/ is written for.
  environment.systemPackages = [ pkgs.via ];
}
