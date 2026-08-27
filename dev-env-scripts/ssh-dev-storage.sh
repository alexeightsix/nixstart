#!/usr/bin/env bash
# Connect to the dev box as root and report storage.
#
# Shares its host and credentials with sync-dev.sh, both kept out of this public
# repo:
#   ~/.config/sync-dev/host      (or $SYNC_DEV_HOST)
#   ~/.config/sync-dev/password  (mode 600, or $SYNC_DEV_PASS)
#
# Usage:
#   ./ssh-dev-storage.sh          # storage report
#   ./ssh-dev-storage.sh -i       # interactive shell on the box
#   ./ssh-dev-storage.sh 'cmd'    # run a command remotely

set -euo pipefail

REMOTE_USER="root"
WATCH_PATH="/storage/dev"

HOST_FILE="${HOME}/.config/sync-dev/host"
PASS_FILE="${HOME}/.config/sync-dev/password"

# --- host ---------------------------------------------------------------
if [[ -z "${SYNC_DEV_HOST:-}" ]]; then
  if [[ -r "$HOST_FILE" ]]; then
    SYNC_DEV_HOST="$(<"$HOST_FILE")"
  else
    echo "No host: create $HOST_FILE or export SYNC_DEV_HOST" >&2
    exit 1
  fi
fi
# A hostname carries no whitespace, so strip whatever the file picked up: a
# stray newline or trailing space fails as a confusing name-resolution error.
REMOTE_HOST="${SYNC_DEV_HOST//[[:space:]]/}"

# --- password -----------------------------------------------------------
if [[ -z "${SYNC_DEV_PASS:-}" ]]; then
  if [[ -r "$PASS_FILE" ]]; then
    SYNC_DEV_PASS="$(<"$PASS_FILE")"
  else
    echo "No password: create $PASS_FILE (chmod 600) or export SYNC_DEV_PASS" >&2
    exit 1
  fi
fi
export SYNC_DEV_PASS

ASKPASS="$(mktemp)"
trap 'rm -f "$ASKPASS"' EXIT
printf '#!/bin/sh\nprintf "%%s\\n" "$SYNC_DEV_PASS"\n' >"$ASKPASS"
chmod 700 "$ASKPASS"
export SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}"

ssh_opts=(-o StrictHostKeyChecking=accept-new
          -o PubkeyAuthentication=no
          -o PreferredAuthentications=password
          -o NumberOfPasswordPrompts=1
          -o ServerAliveInterval=30)

# --- interactive shell --------------------------------------------------
if [[ "${1:-}" == "-i" || "${1:-}" == "--shell" ]]; then
  exec ssh -t "${ssh_opts[@]}" "${REMOTE_USER}@${REMOTE_HOST}"
fi

# --- arbitrary remote command ------------------------------------------
if [[ $# -gt 0 ]]; then
  exec ssh "${ssh_opts[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "$@"
fi

# --- storage report -----------------------------------------------------
REPORT=$(cat <<REMOTE
echo "===== filesystems ====="
df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null

echo
echo "===== inodes ====="
df -i -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | grep -v ' 0%'

echo
echo "===== ${WATCH_PATH} ====="
if [ -d "${WATCH_PATH}" ]; then
  du -sh "${WATCH_PATH}" 2>/dev/null
  echo "-- largest entries --"
  du -sh "${WATCH_PATH}"/* 2>/dev/null | sort -rh | head -20
  echo "-- file count --"
  find "${WATCH_PATH}" -type f 2>/dev/null | wc -l
else
  echo "(does not exist yet)"
fi

echo
echo "===== largest dirs under / (depth 2) ====="
du -xh --max-depth=2 / 2>/dev/null | sort -rh | head -15

echo
echo "===== memory ====="
free -h
REMOTE
)

ssh "${ssh_opts[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "$REPORT"
