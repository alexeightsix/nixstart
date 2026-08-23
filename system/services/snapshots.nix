# Btrfs snapshots and the backup drive.
#
# The `dnf` alias took a snapper snapshot before every package install because
# a Fedora upgrade is not reversible. A NixOS generation is, so snapper here is
# only about /home — the part the store does not cover.
#
# scripts/backup.sh stays a script: it mounts /dev/sda1 by device node, runs a
# full-system rsync and `pkill rsync`s anything already running. That is an
# operator action, not system state.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.nixstart.system.snapshots.home = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Timeline snapshots of /home with snapper (btrfs only).";
  };

  config = lib.mkIf config.nixstart.system.snapshots.home {
    services.snapper = {
      configs.home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ config.nixstart.system.user.name ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
    };

    environment.systemPackages = with pkgs; [
      btrfs-progs
      btrfs-assistant
      snapper
    ];
  };
}
