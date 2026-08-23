# Btrfs snapshots of /home. Only /home.
#
# The root filesystem is deliberately not snapshotted, and that is the whole
# point of doing this on NixOS rather than Fedora. The `dnf` alias took a
# snapper snapshot before every package install because a Fedora transaction
# cannot be undone; here the system is a generation, rollback is a boot menu
# entry, and everything under /nix/store is already reproducible from the
# flake. What none of that covers is the one directory that is neither
# reproducible nor disposable — /home.
#
# The layout matches what the `restore` alias in dotfiles/zsh/alias already
# expects: snapper's own /home/.snapshots/<number>/snapshot/<path>. That
# function fzf-picks an old version of a file or directory out of these
# snapshots, so the two have to agree about where they live.
#
# Separately, scripts/backup.sh stays a script — it mounts /dev/sda1 by device
# node and rsyncs the whole system to it. That is an operator action, and it is
# the off-disk half of the story; snapshots are not backups, since they die
# with the filesystem holding them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.system.snapshots;
  homeFs = config.fileSystems."/home" or null;
in
{
  options.nixstart.system.snapshots = {
    home = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Timeline snapshots of /home with snapper.

        Requires /home to be its own btrfs subvolume — snapper takes snapshots
        of a subvolume, not of a directory, and will refuse to create the
        config otherwise.
      '';
    };

    limits = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {
        hourly = 10;
        daily = 10;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };
      description = ''
        How many timeline snapshots to keep at each granularity. Snapshots are
        cheap on btrfs — they cost only what has changed since — but they are
        not free, and without cleanup they accumulate until the filesystem
        fills. Roughly ten hours, ten days, a month, half a year, two years.
      '';
    };
  };

  config = lib.mkIf cfg.home {
    # A directory cannot be snapshotted, only a subvolume, and the failure if
    # /home is not one is a cryptic snapper error at activation rather than
    # anything that points at this file.
    assertions = [
      {
        assertion = homeFs == null || homeFs.fsType == "btrfs";
        message = ''
          nixstart.system.snapshots.home needs /home on btrfs, but
          fileSystems."/home".fsType is "${toString homeFs.fsType}".
        '';
      }
    ];

    services.snapper = {
      # Timers, rather than the pre/post hooks a package manager would use:
      # nothing here installs software into /home, so there is no transaction
      # to bracket. Time passing is the only thing that changes it.
      snapshotInterval = "hourly";
      cleanupInterval = "1d";

      configs.home = {
        SUBVOLUME = "/home";

        # So `snapper -c home list` and the restore alias work without sudo
        # for the person whose files these are. SYNC_ACL pushes that same
        # permission onto the .snapshots directory itself, which is what makes
        # reading an old file possible rather than only listing it.
        ALLOW_USERS = [ config.nixstart.system.user.name ];
        SYNC_ACL = true;

        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;

        TIMELINE_LIMIT_HOURLY = cfg.limits.hourly;
        TIMELINE_LIMIT_DAILY = cfg.limits.daily;
        TIMELINE_LIMIT_WEEKLY = cfg.limits.weekly;
        TIMELINE_LIMIT_MONTHLY = cfg.limits.monthly;
        TIMELINE_LIMIT_YEARLY = cfg.limits.yearly;

        # Snapshots you take by hand — `snapper -c home create -d "before X"` —
        # are cleaned up on their own count rather than living for ever.
        NUMBER_CLEANUP = true;
        NUMBER_LIMIT = 50;
        NUMBER_MIN_AGE = 1800;

        # Stop taking timeline snapshots when the filesystem is nearly full,
        # rather than making a full disk worse.
        SPACE_LIMIT = "0.5";
        FREE_LIMIT = "0.2";
      };
    };

    environment.systemPackages = with pkgs; [
      snapper
      btrfs-progs
      btrfs-assistant # the GUI, for browsing and diffing snapshots
    ];
  };
}
