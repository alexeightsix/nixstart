# Dell XPS 13 9350 disk layout, verified against the running machine.
#
#   nvme0n1p1  vfat         BOOT   ->  /boot
#   nvme0n1p2  swap         swap
#   nvme0n1p3  crypto_LUKS         ->  cryptroot, btrfs, label "nixos"
#                                      @ @home @nix @log
#
# CPU, microcode, kvm and graphics come from system/hardware/xps13.nix.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usbhid"
    "sd_mod"
  ];

  # Opened in the initrd, before any of the filesystems below can be mounted.
  boot.initrd.luks.devices."cryptroot".device =
    "/dev/disk/by-uuid/4fbacd1a-fb76-4097-957b-01d71887991c";

  # All four subvolumes are on the one decrypted volume, which surfaces as
  # /dev/disk/by-label/nixos once cryptroot is open.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "noatime"
    ];
  };

  # neededForBoot: journald wants /var/log present early.
  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "subvol=@log"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
