# Containers and virtual machines.
#
# Three independent switches. Each also adds the group membership it needs, so
# the account's group list follows from what the machine actually runs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.system.virtualisation;
in
{
  options.nixstart.system.virtualisation = {
    docker = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Docker daemon, compose, and lazydocker.";
    };

    libvirt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "libvirt/QEMU with virt-manager — full virtual machines.";
    };

    incus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Incus: system containers and VMs. This is what the disposable dev
        instances run in.
      '';
    };
  };

  config = lib.mkMerge [

    (lib.mkIf cfg.docker {
      virtualisation.docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      nixstart.system.user.extraGroups = [ "docker" ];
      environment.systemPackages = with pkgs; [
        docker-compose
        lazydocker
      ];
    })

    (lib.mkIf cfg.libvirt {
      virtualisation.libvirtd = {
        enable = true;
        qemu.swtpm.enable = true;
      };
      programs.virt-manager.enable = true;
      nixstart.system.user.extraGroups = [ "libvirtd" ];
      environment.systemPackages = with pkgs; [
        qemu
        virtiofsd
      ];
    })

    (lib.mkIf cfg.incus {
      virtualisation.incus = {
        enable = true;
        # Off: this machine drives incus from the CLI, and the UI would be
        # another listening socket.
        ui.enable = false;
      };
      nixstart.system.user.extraGroups = [ "incus-admin" ];

      # Instances get their addresses from incus's own bridge, so the host
      # firewall has to let its traffic through. Without this, DHCP and DNS
      # inside every instance fail in a way that looks like a broken image.
      networking.firewall.trustedInterfaces = [ "incusbr0" ];
      networking.nftables.enable = true;

      environment.systemPackages = with pkgs; [ incus ];
    })
  ];
}
