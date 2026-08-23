{ lib, ... }:
{
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    efi.canTouchEfiVariables = lib.mkDefault true;
  };

  # stage-02 blacklisted pcspkr and snd_pcsp through /etc/modprobe.d/nobeep.conf.
  boot.blacklistedKernelModules = [
    "pcspkr"
    "snd_pcsp"
  ];
}
