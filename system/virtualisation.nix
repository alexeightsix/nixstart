# Docker.
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
  ];
}
