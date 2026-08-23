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

    # snapper stores its snapshots in <subvolume>/.snapshots and requires that
    # to be a btrfs subvolume in its own right. Nothing creates it: NixOS
    # writes /etc/snapper/configs/home declaratively rather than running
    # `snapper create-config`, which is the command that would have made it.
    # Without it, every snapper run fails with
    #     IO Error (open failed path:/home/.snapshots errno:2)
    # and the first sign of trouble is a failed unit, not a missing snapshot.
    #
    # systemd-tmpfiles' `v` is the obvious tool and is deliberately not used:
    # it silently falls back to a plain directory, which snapper then rejects
    # with `.snapshots is not a btrfs subvolume` — a second failure that looks
    # like the first one was fixed. This is explicit instead, and repairs that
    # directory if a previous attempt left one behind.
    systemd.services.snapper-home-subvolume = {
      description = "Create the /home/.snapshots btrfs subvolume";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      before = [
        "snapper-timeline.service"
        "snapper-cleanup.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        btrfs=${lib.getExe pkgs.btrfs-progs}

        if $btrfs subvolume show /home/.snapshots >/dev/null 2>&1; then
          exit 0
        fi

        # rmdir, never rm -r: it succeeds only on an empty directory, so a
        # path that somehow holds real snapshots is left alone and the unit
        # fails loudly instead of deleting them.
        if [ -e /home/.snapshots ]; then
          rmdir /home/.snapshots
        fi

        $btrfs subvolume create /home/.snapshots
        chmod 0750 /home/.snapshots
      '';
    };

    # Deleting snapshots is the part that generates real IO, and by default it
    # competes with whatever is running at the time. None of this work is
    # urgent: it runs in the background at idle priority so a cleanup pass can
    # never be what makes the desktop stutter.
    systemd.services.snapper-cleanup.serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      IOWeight = 10;
    };

    systemd.services.snapper-timeline.serviceConfig = {
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };

    # Snapshots on the hour and cleanup daily land on round numbers, which is
    # also when everything else in the system wakes up. A few minutes of
    # jitter keeps them out of that pile-up.
    systemd.timers.snapper-timeline.timerConfig.RandomizedDelaySec = "5m";
    systemd.timers.snapper-cleanup.timerConfig.RandomizedDelaySec = "30m";

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

        # Stop taking snapshots once the filesystem is nearly full, rather
        # than making a full disk worse. FREE_LIMIT reads free space straight
        # from the filesystem, so it needs nothing else turned on.
        FREE_LIMIT = "0.2";

        # SPACE_LIMIT is deliberately not set. It measures how much space the
        # snapshots themselves occupy, which btrfs can only answer with
        # qgroups — and qgroups are the single most reliable way to make a
        # btrfs filesystem stall: every delete walks the quota tree, and a
        # rescan can lock the filesystem for minutes at a time. FREE_LIMIT
        # plus the retention counts below bound the space without them.
        #
        # QGROUP = "";
      };
    };

    environment.systemPackages = with pkgs; [
      snapper
      btrfs-progs
      btrfs-assistant # the GUI, for browsing and diffing snapshots
    ];
  };
}
