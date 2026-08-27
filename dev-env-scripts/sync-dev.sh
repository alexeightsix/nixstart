#!/usr/bin/env bash
# Sync ~/dev  ->  the dev box's /storage/dev
# (/storage is the 1 TB volume; / only has ~15 GB free)
#
# Neither the host nor the password is stored here. This repo is public, and an
# address published next to "logs in as root over password auth" is a target.
# Both live in ~/.config/sync-dev/ as `host` and `password` (mode 600), or come
# from $SYNC_DEV_HOST / $SYNC_DEV_PASS.
#
# Usage:
#   ./sync-dev.sh              # sync
#   ./sync-dev.sh -n           # dry run (show what would change)
#   ./sync-dev.sh --no-delete  # don't delete extra files on the remote
#   any extra args are passed straight to rsync

set -euo pipefail

SRC="${HOME}/dev/"
REMOTE_USER="root"
REMOTE_PATH="/storage/dev/"

HOST_FILE="${HOME}/.config/sync-dev/host"
PASS_FILE="${HOME}/.config/sync-dev/password"
EXCLUDE_FILE="${HOME}/.config/sync-dev/excludes"   # optional, one pattern per line

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

# ssh reads the password from this helper instead of a terminal prompt
ASKPASS="$(mktemp)"
trap 'rm -f "$ASKPASS"' EXIT
printf '#!/bin/sh\nprintf "%%s\\n" "$SYNC_DEV_PASS"\n' >"$ASKPASS"
chmod 700 "$ASKPASS"
export SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}"

SSH_CMD="ssh -o StrictHostKeyChecking=accept-new \
             -o PubkeyAuthentication=no \
             -o PreferredAuthentications=password \
             -o NumberOfPasswordPrompts=1 \
             -o ServerAliveInterval=30"

# --- options ------------------------------------------------------------
DELETE="--delete"
EXTRA=()
for arg in "$@"; do
  case "$arg" in
    --no-delete) DELETE="" ;;
    *) EXTRA+=("$arg") ;;
  esac
done

EXCLUDES=()
[[ -r "$EXCLUDE_FILE" ]] && EXCLUDES+=(--exclude-from="$EXCLUDE_FILE")

# --- go -----------------------------------------------------------------
echo "==> ${SRC}  ->  ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

rsync -avhz --partial --info=progress2 \
  ${DELETE} \
  "${EXCLUDES[@]}" \
  -e "$SSH_CMD" \
  "${EXTRA[@]}" \
  "$SRC" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

echo "==> done"
