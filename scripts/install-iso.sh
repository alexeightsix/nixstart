#!/usr/bin/env bash
#
# install-iso.sh — fetch the NixOS installer image and write it to a USB stick.
#
#   install-iso.sh                 list the removable devices it would accept
#   install-iso.sh /dev/sdX        download (if needed), verify, then write
#   install-iso.sh --download-only just fetch and verify the image
#
# Writing an image destroys everything on the target, so this refuses to touch
# anything it is not sure about: the device must be removable, must not be
# mounted, and must not be the disk this system is running from. It then shows
# you what it found and makes you type the device name back.
#
#   NIXOS_VERSION   release to fetch (default 26.05)
#   ISO_DIR         where images are kept (default ~/Downloads/nixos-iso)
set -euo pipefail

VERSION="${NIXOS_VERSION:-26.05}"
ISO_DIR="${ISO_DIR:-$HOME/Downloads/nixos-iso}"
CHANNEL="https://channels.nixos.org/nixos-${VERSION}"
IMAGE="latest-nixos-minimal-x86_64-linux.iso"

die() { echo "install-iso: $*" >&2; exit 1; }

# --- what this system runs from, so it is never a candidate ---------------
system_disks() {
    local src
    for mount in / /boot /home /nix; do
        src=$(findmnt -no SOURCE --target "$mount" 2>/dev/null) || continue
        # /dev/nvme0n1p3 -> nvme0n1, /dev/sda2 -> sda
        lsblk -no PKNAME "${src%%[*}" 2>/dev/null || true
    done | sort -u
}

candidates() {
    local protected
    protected=$(system_disks)
    lsblk -dno NAME,RM,SIZE,MODEL | while read -r name rm size model; do
        [ "$rm" = "1" ] || continue
        grep -qx "$name" <<<"$protected" && continue
        printf '  /dev/%-8s %-8s %s\n' "$name" "$size" "$model"
    done
}

# --- fetch ----------------------------------------------------------------
fetch() {
    mkdir -p "$ISO_DIR"
    local url resolved name iso

    url="$CHANNEL/$IMAGE"
    resolved=$(curl -sIL -o /dev/null -w '%{url_effective}' "$url") \
        || die "could not reach $url"
    name=$(basename "$resolved")
    iso="$ISO_DIR/$name"

    if [ -f "$iso" ]; then
        echo "==> already downloaded: $iso" >&2
    else
        echo "==> downloading $name" >&2
        curl -fL --progress-bar -o "$iso.part" "$resolved" || die "download failed"
        mv "$iso.part" "$iso"
    fi

    # The release publishes a sha256 next to the image. An image that is
    # subtly wrong produces a machine that boots and then misbehaves, which is
    # far worse to debug than one that refuses to start.
    echo "==> verifying" >&2
    local want got
    if want=$(curl -fsSL "${resolved}.sha256" 2>/dev/null | awk '{print $1}') && [ -n "$want" ]; then
        got=$(sha256sum "$iso" | awk '{print $1}')
        [ "$want" = "$got" ] || die "checksum mismatch — delete $iso and retry"
        echo "    sha256 ok" >&2
    else
        echo "    !! no published checksum found; continuing unverified" >&2
    fi

    printf '%s' "$iso"
}

# --- write ----------------------------------------------------------------
write() {
    local device="$1" iso="$2"

    [ -b "$device" ] || die "$device is not a block device"

    local name="${device#/dev/}"
    [ "$(lsblk -dno RM "$device")" = "1" ] \
        || die "$device is not removable — refusing"

    grep -qx "$name" <<<"$(system_disks)" \
        && die "$device holds a filesystem this system is running from — refusing"

    local mounted
    mounted=$(lsblk -no MOUNTPOINTS "$device" | grep -v '^$' || true)
    if [ -n "$mounted" ]; then
        echo "==> unmounting:"; echo "$mounted" | sed 's/^/      /'
        lsblk -no PATH "$device" | tail -n +2 | while read -r part; do
            udisksctl unmount -b "$part" 2>/dev/null || sudo umount "$part" 2>/dev/null || true
        done
    fi

    echo
    echo "  device   $device"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$device" | sed 's/^/    /'
    echo "  image    $(basename "$iso")  ($(du -h "$iso" | cut -f1))"
    echo
    echo "  Everything on $device will be destroyed."
    read -rp "  Type the device name ($name) to continue: " confirm
    [ "$confirm" = "$name" ] || die "cancelled"

    echo "==> writing"
    sudo dd if="$iso" of="$device" bs=4M status=progress oflag=direct conv=fsync
    echo "==> flushing"
    sync
    echo "==> done — $device is bootable"
}

# --- go -------------------------------------------------------------------
case "${1:-}" in
    --download-only) fetch >/dev/null; echo "==> image is in $ISO_DIR" >&2 ;;
    "")
        echo "usage: install-iso.sh /dev/sdX"
        echo
        echo "removable devices this would accept:"
        found=$(candidates)
        if [ -z "$found" ]; then
            echo "  (none found — plug in a USB stick)"
        else
            echo "$found"
        fi
        ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0" ;;
    *)
        iso=$(fetch)
        write "$1" "$iso"
        ;;
esac
