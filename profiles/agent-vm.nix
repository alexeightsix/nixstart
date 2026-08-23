# A micro VM that exists to run an agent.
#
# Imported by a guest configuration, whatever builds it — microvm.nix, an Incus
# VM, a plain qemu image. It brings the shared dev environment and nothing
# else: no X, no desktop, no home-manager generation. The agent gets the same
# shell and the same tools it would have on the desktop, in a machine that can
# be thrown away.
#
# Give it a language and a project mount and it is complete:
#
#   {
#     imports = [ ./profiles/agent-vm.nix ];
#     networking.hostName = "agent-01";
#     nixstart.devEnv.languages = [ "node" ];
#     nixstart.agentVm.authorizedKeys = [ "ssh-ed25519 AAAA..." ];
#   }
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.agentVm;
in
{
  options.nixstart.agentVm = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "agent";
      description = "The account the agent runs as.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Keys that may log in. Password authentication is off: a VM that runs
        an agent is a machine that will be reachable from somewhere else, and
        it is not worth being casual about.
      '';
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "/workspace";
      description = "Where the project is mounted. The shell starts here.";
    };
  };

  config = {
    nixstart.devEnv.enable = true;

    users.users.${cfg.user} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # No password on the account at all, so ssh keys are the only way in and
    # there is nothing to guess. sudo is passwordless because there is no
    # password to give it.
    security.sudo.wheelNeedsPassword = false;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # The shell opens in the project rather than in a home directory nobody
    # put anything in.
    environment.variables.WORKSPACE = cfg.workspace;
    programs.zsh.shellInit = ''
      [ -d "${cfg.workspace}" ] && cd "${cfg.workspace}"
    '';

    # Nothing graphical, and a guest should not carry documentation it will
    # never be read on.
    documentation.enable = false;
    documentation.man.enable = false;
    services.xserver.enable = false;

    # These guests are disposable and their disks are small, so the store is
    # collected far harder than on a real machine — mkForce because the
    # workstation default of 30 days would fill the image.
    nix.gc = {
      automatic = true;
      dates = lib.mkForce "daily";
      options = lib.mkForce "--delete-older-than 3d";
    };

    networking.firewall.allowedTCPPorts = [ 22 ];
    system.stateVersion = lib.mkDefault "25.05";
  };
}
