# Containers and virtual machines.
#
# One file, three independent switches, because the three arrived by three
# different routes and no single place said which a machine had:
#
#   docker    stage-02, from Docker's own Fedora repository
#   libvirt   stage-01, as `libvirt qemu virt-manager` in the dnf list, with
#             nothing enabling the daemon or adding the user to a group
#   incus     never installed by any stage at all — yet it is running on this
#             machine, hosting the `tv` container and an `sbx` project, and
#             .zshrc has a whole DEV_VIA breadcrumb mechanism whose comment
#             says "lazyincus sets DEV_VIA on the way in". A rebuilt machine
#             would have come back without any of it.
#
# Each option also adds the group membership it needs. stage-02, stage-07 and
# stage-09 each ran their own `usermod -aG`, so the real group list only
# existed as the union of whichever scripts you had remembered to run.
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
        instances run in — the ones `link.sh --headless` provisions.
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
        lazydocker # was `GOBIN=/usr/local/bin go install ...@latest` in stage-01
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
        # The web UI is off: this machine drives incus from the CLI and
        # lazyincus, and the UI would be another listening socket.
        ui.enable = false;
      };
      nixstart.system.user.extraGroups = [ "incus-admin" ];

      # Instances get their addresses from incus's own bridge, so the host
      # firewall has to let its traffic through — without this, DHCP and DNS
      # inside every instance fail in a way that looks like a broken image.
      networking.firewall.trustedInterfaces = [ "incusbr0" ];
      networking.nftables.enable = true;

      environment.systemPackages = with pkgs; [ incus ];
    })
  ];
}
