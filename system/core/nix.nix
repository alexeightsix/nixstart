# Nix itself.
#
# stage-08 installed the daemon with the upstream shell installer and left a
# note that SELinux had to be disabled first. On NixOS none of that exists.
{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        config.nixstart.system.user.name
      ];
      auto-optimise-store = true;
      warn-dirty = false;
    };

    # scripts/update-packages.sh ran `dnf upgrade`, `atuin update`, `claude
    # update`, `flatpak update`, `npm update -g`, `rustup update`, `cargo
    # install-update --all` and `go install ...@latest` in sequence, each with
    # its own idea of what "current" means. Here the lockfile is the only
    # thing that moves, and `nixos-rebuild` is the only thing that applies it.
    # Two layers of garbage collection, because a scheduled one alone is not
    # enough: a heavy week of rebuilds can fill a disk long before the next
    # timer fires.
    #
    #   min-free / max-free   the important one. The daemon collects on its
    #                         own the moment free space drops below 5 GiB,
    #                         and stops once it has recovered 20 GiB. This is
    #                         what actually prevents a full disk.
    #   gc.automatic          the routine sweep, for generations nothing has
    #                         referenced in a month.
    settings.min-free = 5 * 1024 * 1024 * 1024;
    settings.max-free = 20 * 1024 * 1024 * 1024;

    gc = {
      automatic = true;
      dates = "weekly";
      randomizedDelaySec = "45min";
      persistent = true;
      options = "--delete-older-than 30d";
    };

    # Hard-link identical files in the store. Runs at idle priority below, so
    # the scan is never what makes the machine feel slow.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    # `nix shell nixpkgs#foo` resolves against the same nixpkgs the system was
    # built from, rather than a channel that drifts behind it.
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  # Rollback is a boot menu entry now, which is what the `dnf` alias was
  # reaching for when it took a snapper snapshot before every install.
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 20;

  system.stateVersion = lib.mkDefault "25.05";

  # Collecting and optimising are both IO-bound and neither is urgent.
  systemd.services.nix-gc.serviceConfig = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };
  systemd.services.nix-optimise.serviceConfig = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };

  # Logs are the other thing that grows without anyone watching it.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemMaxFileSize=128M
    MaxRetentionSec=1month
  '';

  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    nix-index
    nixd
    nixfmt
    ncdu # what is actually taking up the space
  ];
}
