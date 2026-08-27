#!/usr/bin/env bash
#
# Full-system rsync onto the Timeshift disk. Run as root — it mounts.
#
# The account is whoever invoked sudo, so the home-directory excludes follow
# the operator rather than a name baked into the script.
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
MOUNT="/run/media/$TARGET_USER/Timeshift"

pkill rsync
umount /dev/sda1
mkdir -p "$MOUNT"
mount /dev/sda1 "$MOUNT"

# Double-quoted, not single: these patterns interpolate $TARGET_HOME.
rsync -avh -W --delete --progress \
  --exclude='/nix/*' \
  --exclude='/dev/*' \
  --exclude='.qcow2' \
  --exclude="$TARGET_HOME/.cache/*" \
  --exclude='/var/tmp/*' \
  --exclude='/proc/*' \
  --exclude='/sys/*' \
  --exclude='/tmp/*' \
  --exclude='/run/*' \
  --exclude='/mnt/*' \
  --exclude='/media/*' \
  --exclude="$TARGET_HOME/.local/share/Trash*" \
  --exclude="swapfile" \
  --exclude="$TARGET_HOME/.mozilla/" \
  --exclude="lost+found" \
  --exclude="$TARGET_HOME/.alex" \
  --exclude=".snapshots" \
  / "$MOUNT"

umount /dev/sda1
