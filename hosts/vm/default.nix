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

  swapDevices = [ ];
  nixpkgs.hostPlatform = "x86_64-linux";

  kickstart.system = {
    user.name = "alex";
    desktop.enable = true;
    apps.gui = true;
    virtualisation.docker = true;
  };

  # The only way in. Password auth because this is a throwaway with no key
  # provisioned; system/services/openssh.nix defaults it off for real hosts.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  users.users.alex.initialPassword = "test";
  users.users.root.initialPassword = "test";
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # The incus agent, so `incus exec`/`incus file push` work against the
  # installed system the way they do against a container.
  virtualisation.incus.agent.enable = true;

  home-manager.users.alex.kickstart.home = {
    checkout = "/home/alex/kickstart";
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
