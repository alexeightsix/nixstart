# The account, and the groups the enabled modules need it in.
#
# stage-02, stage-07 and stage-09 each ran their own `usermod -aG`, so the
# group list only existed as the union of three scripts you had to have run.
{ config, pkgs, ... }:
let
  cfg = config.nixstart.system;
in
{
  programs.zsh.enable = true;

  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.fullName;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ]
    ++ cfg.user.extraGroups;
  };

  # stage-03 finished with `chown -R $(id -un) $HOME` to undo the damage from
  # the stages that ran as root. Nothing here writes into a home directory as
  # root, so there is nothing to repair.
  security.sudo.wheelNeedsPassword = true;
}
