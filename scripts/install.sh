#!/usr/bin/env bash
#
# install.sh — install a host from this flake onto a disk.
#
#   install.sh <host> <device> [options]
#   install.sh laptop  /dev/nvme0n1 --luks --swap 40G
#
#   --luks          encrypt everything but the ESP (asks for a passphrase)
#   --swap SIZE     swap partition; size it >= RAM if you want hibernate
#   --keep-home     do not format; reuse the existing @home subvolume
#   --dry-run       print the plan and stop
#
# Layout is btrfs with subvolumes, because nixstart.system.snapshots.home
# needs /home to be a subvolume rather than a directory:
#
#   part1  1GiB   vfat, label BOOT   -> /boot
#   part2  swap   (only with --swap)
#   part3  rest   btrfs, label nixos -> @ / @home / @nix / @log
#
# This formats a disk. It refuses to touch one this system is running from,
# shows you the plan, and makes you type the device name back.
set -euo pipefail

die() { echo "install: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HOST=""; DEVICE=""; LUKS=0; SWAP=""; KEEP_HOME=0; DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --luks)      LUKS=1 ;;
        --swap)      SWAP="${2:?--swap needs a size}"; shift ;;
        --keep-home) KEEP_HOME=1 ;;
        --dry-run)   DRY=1 ;;
        -h|--help)   awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
        -*)          die "unknown option $1" ;;
        *)           if [ -z "$HOST" ]; then HOST=$1; elif [ -z "$DEVICE" ]; then DEVICE=$1; else die "unexpected $1"; fi ;;
    esac
    shift
done

[ -n "$HOST" ] && [ -n "$DEVICE" ] || { awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 2; }
[ -d "$REPO/hosts/$HOST" ] || die "no such host: $HOST (have: $(ls "$REPO/hosts" | tr '\n' ' '))"
[ -b "$DEVICE" ] || die "$DEVICE is not a block device"
[ "$(id -u)" = 0 ] || die "run as root"

# --- refuse the disk we are running from ----------------------------------
for mount in / /nix /boot; do
    src=$(findmnt -no SOURCE --target "$mount" 2>/dev/null) || continue
    parent=$(lsblk -no PKNAME "${src%%[*}" 2>/dev/null | head -1) || true
    [ -n "$parent" ] && [ "/dev/$parent" = "$DEVICE" ] \
        && die "$DEVICE is where this system is running from"
done

# p1/p2 on nvme and mmc, 1/2 on sd
part() { case "$DEVICE" in *nvme*|*mmcblk*) echo "${DEVICE}p$1" ;; *) echo "${DEVICE}$1" ;; esac; }
ESP=$(part 1)
if [ -n "$SWAP" ]; then SWAPPART=$(part 2); ROOTPART=$(part 3); else SWAPPART=""; ROOTPART=$(part 2); fi
ROOTFS="$ROOTPART"; [ $LUKS -eq 1 ] && ROOTFS=/dev/mapper/cryptroot

# --- everything this needs, checked before anything is destroyed ----------
# A tool that turns out to be missing halfway through leaves a disk that has
# been partitioned but not formatted, which is worse than not starting.
need=(parted mkfs.fat mkfs.btrfs btrfs udevadm blkid nixos-generate-config nixos-install)
[ -n "$SWAP" ] && need+=(mkswap swapon)
[ $LUKS -eq 1 ] && need+=(cryptsetup)

missing=()
for tool in "${need[@]}"; do command -v "$tool" >/dev/null || missing+=("$tool"); done
if [ ${#missing[@]} -gt 0 ]; then
    echo "install: missing: ${missing[*]}" >&2
    echo "         The NixOS installer ISO has all of these. On another system:" >&2
    echo "           nix shell nixpkgs#parted nixpkgs#dosfstools nixpkgs#btrfs-progs nixpkgs#cryptsetup" >&2
    exit 1
fi

# --- the plan -------------------------------------------------------------
echo
echo "  host        $HOST"
echo "  device      $DEVICE"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$DEVICE" | sed 's/^/    /'
echo
echo "  $ESP  ->  1GiB vfat, label BOOT, mounted at /boot"
[ -n "$SWAP" ] && echo "  $SWAPPART  ->  $SWAP swap"
echo "  $ROOTPART  ->  rest, btrfs label nixos$([ $LUKS -eq 1 ] && echo ', inside LUKS')"
echo "                 @ -> /   @home -> /home   @nix -> /nix   @log -> /var/log"
[ $KEEP_HOME -eq 1 ] && echo "  @home is kept, not reformatted"
echo

[ $DRY -eq 1 ] && { echo "(dry run — nothing done)"; exit 0; }

echo "  Everything on $DEVICE will be destroyed."
read -rp "  Type the device name ($(basename "$DEVICE")) to continue: " confirm
[ "$confirm" = "$(basename "$DEVICE")" ] || die "cancelled"

# --- partition ------------------------------------------------------------
step "partitioning"
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
cryptsetup close cryptroot 2>/dev/null || true

parted -s "$DEVICE" -- mklabel gpt
parted -s "$DEVICE" -- mkpart ESP fat32 1MiB 1GiB
parted -s "$DEVICE" -- set 1 esp on
if [ -n "$SWAP" ]; then
    parted -s "$DEVICE" -- mkpart swap linux-swap 1GiB "$SWAP"
    parted -s "$DEVICE" -- mkpart root 2>/dev/null btrfs "$SWAP" 100% \
        || parted -s "$DEVICE" -- mkpart root btrfs "$SWAP" 100%
else
    parted -s "$DEVICE" -- mkpart root btrfs 1GiB 100%
fi
udevadm settle; sleep 2

step "formatting"
mkfs.fat -F32 -n BOOT "$ESP"
[ -n "$SWAP" ] && { mkswap -L swap "$SWAPPART"; swapon "$SWAPPART"; }

if [ $LUKS -eq 1 ]; then
    step "encrypting $ROOTPART"
    cryptsetup luksFormat --type luks2 "$ROOTPART"
    cryptsetup open "$ROOTPART" cryptroot
fi

# --- subvolumes -----------------------------------------------------------
# @home is separate so snapper can snapshot it; @nix and @log are separate so
# neither ends up inside a snapshot of /.
step "creating subvolumes"
if [ $KEEP_HOME -eq 1 ]; then
    mount "$ROOTFS" /mnt
    btrfs subvolume list /mnt | grep -q ' @home$' || die "--keep-home: no @home subvolume on $ROOTFS"
    for sv in @ @nix @log; do
        btrfs subvolume delete "/mnt/$sv" 2>/dev/null || true
        btrfs subvolume create "/mnt/$sv"
    done
    umount /mnt
else
    mkfs.btrfs -f -L nixos "$ROOTFS"
    mount "$ROOTFS" /mnt
    for sv in @ @home @nix @log; do btrfs subvolume create "/mnt/$sv"; done
    umount /mnt
fi

step "mounting"
OPTS="compress=zstd,noatime"
mount -o "subvol=@,$OPTS" "$ROOTFS" /mnt
mkdir -p /mnt/{boot,home,nix,var/log}
mount -o "subvol=@home,$OPTS" "$ROOTFS" /mnt/home
mount -o "subvol=@nix,$OPTS" "$ROOTFS" /mnt/nix
mount -o "subvol=@log,$OPTS" "$ROOTFS" /mnt/var/log
mount "$ESP" /mnt/boot

# --- hardware configuration ----------------------------------------------
# The one file that cannot be written ahead of time. It replaces the
# placeholder in hosts/<host>/ so the flake describes this actual machine.
step "generating hardware-configuration.nix for $HOST"
nixos-generate-config --root /mnt --no-filesystems
install -m 0644 /mnt/etc/nixos/hardware-configuration.nix \
    "$REPO/hosts/$HOST/hardware-configuration.nix"

{
    echo ""
    echo "# Filesystems, written by scripts/install.sh."
    echo "{ ... }:"
    echo "{"
    echo "  fileSystems.\"/\"        = { device = \"/dev/disk/by-label/nixos\"; fsType = \"btrfs\"; options = [ \"subvol=@\" \"compress=zstd\" \"noatime\" ]; };"
    echo "  fileSystems.\"/home\"    = { device = \"/dev/disk/by-label/nixos\"; fsType = \"btrfs\"; options = [ \"subvol=@home\" \"compress=zstd\" \"noatime\" ]; };"
    echo "  fileSystems.\"/nix\"     = { device = \"/dev/disk/by-label/nixos\"; fsType = \"btrfs\"; options = [ \"subvol=@nix\" \"compress=zstd\" \"noatime\" ]; };"
    echo "  fileSystems.\"/var/log\" = { device = \"/dev/disk/by-label/nixos\"; fsType = \"btrfs\"; options = [ \"subvol=@log\" \"compress=zstd\" \"noatime\" ]; };"
    echo "  fileSystems.\"/boot\"    = { device = \"/dev/disk/by-label/BOOT\"; fsType = \"vfat\"; };"
    [ -n "$SWAP" ] && echo "  swapDevices = [ { device = \"/dev/disk/by-label/swap\"; } ];" || echo "  swapDevices = [ ];"
    if [ $LUKS -eq 1 ]; then
        uuid=$(blkid -s UUID -o value "$ROOTPART")
        echo "  boot.initrd.luks.devices.cryptroot.device = \"/dev/disk/by-uuid/$uuid\";"
    fi
    echo "}"
} > "$REPO/hosts/$HOST/filesystems.nix"

grep -q "filesystems.nix" "$REPO/hosts/$HOST/default.nix" \
    || sed -i '0,/imports = \[/s//imports = [\n    .\/filesystems.nix/' "$REPO/hosts/$HOST/default.nix"

# --- install --------------------------------------------------------------
step "installing $HOST (this takes a while)"
export NIX_CONFIG="experimental-features = nix-command flakes"

# The dotfiles used to be a separate `path:` input, which meant hunting for a
# ~/kickstart checkout here and passing --override-input so the installer did
# not fail on a path that does not exist in the installer environment. They
# live in this repository now, so there is nothing to find and nothing to
# override.
nixos-install --flake "$REPO#$HOST" --no-root-password

step "done"
echo "  Reboot, log in as the account in hosts/$HOST/default.nix, and run passwd."
[ $KEEP_HOME -eq 1 ] && echo "  /home was kept — check that uid 1000 still owns it."
