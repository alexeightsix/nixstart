# A disposable Incus VM, for testing this configuration before a real machine
# is committed to it.
#
# Same modules as `desktop`, so what is being tested is the real thing — the
# differences are the ones that are actually true of a VM: virtio disks,
# no Bluetooth, no RAM RGB, no keyboard to flash, and an ssh login because
# there is no physical console.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.hostName = "vm";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  # A second disk, btrfs, with /home as its own subvolume — the layout
  # nixstart.system.snapshots.home needs. The desktop has the same shape on one
  # disk; what matters to snapper is that /home is a subvolume, not which
  # device it lives on.
  fileSystems."/home" = {
    device = "/dev/disk/by-label/home";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
    ];
  };

  nixstart.system.snapshots.home = true;

  swapDevices = [ ];
  nixpkgs.hostPlatform = "x86_64-linux";

  nixstart.system = {
    user.name = "alex";
    desktop.enable = true;
    apps.gui = true;
    virtualisation.docker = true;
  };

  # The only way in. Password auth because this is a throwaway with no key
  # provisioned; system/services/openssh.nix defaults it off for real hosts.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  nixstart.system.user.initialPassword = "test";
  users.users.root.initialPassword = "test";
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # The incus agent, so `incus exec`/`incus file push` work against the
  # installed system the way they do against a container.
  virtualisation.incus.agent.enable = true;

  home-manager.users.alex.nixstart.home = {
    checkout = "/home/alex/nixstart";
    user.email = "alexlatour@gmail.com";
    desktop.weather.enable = true;
    desktop.weather.location = "Montreal";
    desktop.statusBar = "desktop";
    languages = [
      "go"
      "node"
      "lua"
    ];
    agents = false;
  };
}
