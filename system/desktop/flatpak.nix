# stage-04 added the Flathub remote, installed eight applications and then
# symlinked each one's exported binary into /usr/bin so it could be launched by
# name. All eight are in nixpkgs — see desktop/apps.nix — so this is off unless
# a host asks for it.
{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  config = lib.mkIf config.nixstart.system.apps.flatpak {
    services.flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      packages = [ ];
      uninstallUnmanaged = true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ inputs.nixpkgs.legacyPackages.x86_64-linux.xdg-desktop-portal-gtk ];
      config.common.default = "gtk";
    };
  };
}
