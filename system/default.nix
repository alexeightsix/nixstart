# Every NixOS module in this repository. Importing this one imports the lot;
# each of them is inert until the matching `kickstart.*` option is turned on,
# so a host file is a list of decisions rather than a list of imports.
{
  imports = [
    ./options.nix

    ./core/nix.nix
    ./core/nix-ld.nix
    ./core/boot.nix
    ./core/locale.nix
    ./core/networking.nix
    ./core/users.nix
    ./core/secrets.nix

    ./desktop/x11.nix
    ./desktop/i3.nix
    ./desktop/audio.nix
    ./desktop/fonts.nix
    ./desktop/flatpak.nix
    ./desktop/apps.nix

    ./hardware/bluetooth.nix
    ./hardware/keychron.nix
    ./hardware/rgb.nix
    ./hardware/xps13.nix

    ./services/openssh.nix
    ./services/tailscale.nix
    ./services/snapshots.nix

    ./virtualisation.nix
    ./dev-env.nix
    ./vm-variant.nix

    ./home.nix
  ];
}
