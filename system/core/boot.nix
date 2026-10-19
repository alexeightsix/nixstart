{ lib, ... }:
{
  boot.loader = {
    systemd-boot = {
      enable = lib.mkDefault true;

      # Three entries in the boot menu, not every generation ever built. The
      # ESP is 1 GiB and each entry drags a kernel and initrd into it, so an
      # unbounded menu is what eventually fills /boot and makes the next
      # switch fail mid-install.
      #
      # This bounds the menu only. The system profile keeps its generations
      # until nix.gc sweeps them at 30 days (see system/core/nix.nix), which
      # is deliberate: a generation older than the third newest is still
      # rollback-able with `nixos-rebuild switch --rollback`, it just is not
      # offered at boot.
      configurationLimit = 3;
    };
    efi.canTouchEfiVariables = lib.mkDefault true;
  };

  # stage-02 blacklisted pcspkr and snd_pcsp through /etc/modprobe.d/nobeep.conf.
  boot.blacklistedKernelModules = [
    "pcspkr"
    "snd_pcsp"
  ];
}
