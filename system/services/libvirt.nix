{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.kickstart.system.virtualisation.libvirt {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };
    programs.virt-manager.enable = true;
    kickstart.system.user.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [ qemu ];
  };
}
