# Every NixOS module in this repository. system/machine.nix imports this.
{
  imports = [
    ./options.nix

    ./nix/settings.nix
    ./nix/nix-ld.nix

    ./boot/loader.nix
    ./boot/easy-boot.nix

    ./core/locale.nix
    ./core/networking.nix
    ./core/users.nix
    ./core/secrets.nix

    ./desktop/x11.nix
    ./desktop/keyd.nix
    ./desktop/i3.nix
    ./desktop/audio.nix
    ./desktop/fonts.nix
    ./desktop/apps.nix

    ./hardware/bluetooth.nix
    ./hardware/keychron.nix
    ./hardware/xps13.nix

    ./services/openssh.nix
    ./services/tailscale.nix
    ./services/snapshots.nix
    ./services/docker.nix

    ./home.nix
  ];
}
