# The dev environment as a NixOS module, for guests that have no home-manager.
#
# This is what a micro VM running an agent imports. It is the same definition
# the desktop and the dev shell use — lib/dev-env.nix — put into
# environment.systemPackages instead of home.packages, so a VM's shell has the
# same tools without carrying the whole desktop configuration.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.devEnv;

  devEnv = import ../lib/dev-env.nix {
    inherit pkgs lib;
    inherit (cfg) languages agents databases;
  };
in
{
  options.nixstart.devEnv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the shared development environment system-wide. For machines
        with no per-user home-manager generation — micro VMs, dev boxes.
      '';
    };

    languages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Toolchains this guest needs. A VM running one agent on one project
        wants one language, not the desktop's six.
      '';
    };

    agents = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "claude-code, codex, opencode and their runtimes.";
    };

    databases = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "mariadb and postgresql clients.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = devEnv.packages;
    environment.variables = devEnv.env;

    programs.zsh.enable = true;
    users.defaultUserShell = pkgs.zsh;

    # An agent that shells out to a dynamically linked binary it downloaded
    # itself needs this as much here as on the desktop.
    programs.nix-ld.enable = true;
  };
}
