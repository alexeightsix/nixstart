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
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
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

  environment.systemPackages = with pkgs; [
    nix-index
    nixd
    nixfmt
  ];
}
