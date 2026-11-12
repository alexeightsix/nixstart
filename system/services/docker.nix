# Docker.
{ pkgs, ... }:
{
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
}
