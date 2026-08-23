# Booting a host's configuration in a window, without installing it.
#
#   nixos-rebuild build-vm --flake .#desktop
#   ./result/bin/run-desktop-vm
#
# `system.build.vm` takes the real configuration and boots it under qemu
# against a throwaway disk image, so what you are looking at is the actual
# desktop — i3, the bar, Ghostty, the theme — and not an approximation of it.
# Nothing is installed and nothing on the host is touched; delete the .qcow2
# it leaves behind and it is as though it never ran.
#
# `virtualisation.vmVariant` applies only to that build, so none of this
# reaches the real machine.
{ config, lib, ... }:
{
  virtualisation.vmVariant = {

    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 16 * 1024;

      # A window rather than a serial console, which is the whole point here.
      graphics = true;
      qemu.options = [
        "-vga none"
        "-device virtio-gpu-pci"
        "-display gtk,gl=on,show-cursor=on"
      ];

      # The host's Nix store is mounted read-only instead of being copied into
      # the image, so the VM starts in seconds rather than after a long build.
      writableStore = true;

      # Anything that would need real hardware.
      useNixStoreImage = false;
    };

    # Straight to the desktop. A VM you are booting to look at should not stop
    # at a login prompt for a password that only exists to satisfy the
    # assertion in system/core/users.nix.
    services.displayManager.autoLogin = {
      enable = true;
      user = config.nixstart.system.user.name;
    };

    # A resolution worth looking at, and no fixed xrandr line — the virtual
    # display is not the host's monitor.
    home-manager.users.${config.nixstart.system.user.name}.nixstart.home.desktop = {
      monitors = lib.mkForce "";
      autorandr = lib.mkForce false;
      # The weather wallpaper needs the network and a base image; in a
      # throwaway VM the static one is the honest thing to show.
      weather.enable = lib.mkForce false;
    };

    # None of this exists in a VM, and each would fail a unit at boot.
    nixstart.system.hardware = {
      rgb = lib.mkForce false;
      keychron = lib.mkForce false;
      bluetooth = lib.mkForce false;
      xps13 = lib.mkForce false;
    };
    nixstart.system.snapshots.home = lib.mkForce false;
    nixstart.system.tailscale = lib.mkForce false;

    # Passwordless, because it is a window on your own desktop.
    users.users.${config.nixstart.system.user.name}.initialPassword = lib.mkForce "vm";
    security.sudo.wheelNeedsPassword = lib.mkForce false;
  };
}
