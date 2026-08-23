# stage-02 added Docker's own Fedora repository and installed docker-ce from it.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.kickstart.system.virtualisation.docker {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    kickstart.system.user.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [
      docker-compose
      lazydocker # was `GOBIN=/usr/local/bin go install ...@latest` in stage-01
    ];
  };
}
