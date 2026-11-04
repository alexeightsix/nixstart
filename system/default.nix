# Every NixOS module in this repository. system/machine.nix imports this.
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
    ./core/easy-boot.nix

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

    ./virtualisation.nix

    ./home.nix
  ];
}
