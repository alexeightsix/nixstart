# Dual-boot Windows 11 — what to do next

Written 2026-08-29. Target machine: the NixOS laptop, disk `/dev/nvme0n1`
(SK hynix 512GB). Everything below assumes you booted **this** USB stick.

---

## Already done (don't redo these)

Both of these ran successfully on 2026-08-29 and were verified:

| Layer | Was | Now |
|---|---|---|
| btrfs filesystem | 439.67 GiB | **285 GiB** |
| LUKS mapping `cryptroot` | 439.67 GiB | **289 GiB** |
| Partition `nvme0n1p3` | 439.67 GiB | **unchanged — this is the remaining job** |

The layers are nested inside-out on purpose: filesystem smaller than LUKS,
LUKS smaller than the partition. Nothing on the system can read or write
past sector 606,109,696. That is what makes the next step safe.

The 4 GiB gap between btrfs (285) and LUKS (289) is deliberate slack.
You reclaim it in Step 3.

---

## Current disk layout

```
disk total          1,000,215,216 sectors
p1  start     2,048   size   2,095,104   1023 MiB  ESP  /boot
p2  start 2,097,152   size  76,027,904   36.25 GiB swap (unused)
p3  start 78,125,056  size 922,089,472  439.67 GiB LUKS -> btrfs
```

---

## Step 1 — Shrink p3 (do this from this USB)

Boot this stick. Ventoy is gone — the stick is now a straight `dd` of the
GParted Live image, so it boots directly into GParted with no menu to pick
from.

**Do NOT unlock the LUKS volume.** Leave it locked. You are only editing
the partition table — no data moves, nothing is reformatted.

Resize `nvme0n1p3` to:

```
296,639 MiB          (= 607,516,672 sectors)
```

Leave the freed space at the end **unallocated and unformatted**:

```
153,600 MiB          (= 150 GiB, = 314,572,800 sectors)
```

The Windows installer wants raw unallocated space so it can create its own
~600 MB recovery partition. Do not format it as NTFS.

### Why these numbers are safe

The LUKS payload ends at sector 606,109,696. The new partition ends at
685,641,727. That is 687 MiB of headroom — the edit physically cannot
clip encrypted data.

Start sector 78,125,056 must NOT change. Keeping it preserves the PARTUUID,
which is what `/etc/fstab` and the boot entries reference.

### If you prefer the command line

Boot the NixOS ISO instead and run:

```sh
sfdisk -d /dev/nvme0n1 > /tmp/table.bak      # back up first
echo ',607516672' | sfdisk -N 3 /dev/nvme0n1
```

`-N 3` edits only partition 3 and keeps its start sector and UUID.

---

## Step 2 — Install Windows 11

The stick only holds GParted now, so it has to be rewritten as Windows
install media first. Do that from NixOS after Step 1, before rebooting:
`Win11_25H2_English_x64_v2.iso` is still in `~/Downloads`.

Install into the 150 GiB of unallocated space. Windows will carve out its
own recovery partition — let it.

### Two things that will bite you

**Keep Secure Boot OFF.** It is currently disabled in your firmware and it
must stay that way. Turning it on for Windows stops NixOS from booting —
systemd-boot is unsigned on this machine and would need lanzaboote. Windows
11 installs fine without it; TPM2 is present, which is the part Windows
actually checks.

**Windows will steal the boot order.** Your ESP has 817 MiB free, plenty for
both bootloaders, and systemd-boot auto-detects `bootmgfw.efi` so Windows
will appear in your normal boot menu. But the firmware may set Windows as
the default. Fix it in the BIOS boot order after installation.

---

## Step 3 — Back in NixOS, reclaim the slack

After Windows is installed and you have booted back into NixOS:

```sh
sudo cryptsetup resize cryptroot
sudo btrfs filesystem resize max /
```

This grows the LUKS mapping and then the filesystem to fill the new ~289 GiB
partition. Order matters: LUKS first, then btrfs. (Growing is outside-in;
shrinking was inside-out.)

Verify with:

```sh
df -h /            # should show ~289G
lsblk -o NAME,SIZE,FSTYPE /dev/nvme0n1
```

---

## BEFORE YOU START: back up

Your snapper snapshots live on `p3` — the partition being edited. They do
not survive a mistake on it. `scripts/backup.sh` in ~/nixstart is the
off-disk half and it is **manual**. Run it and connect the backup drive.

---

## What is on this stick

Only GParted Live 1.8.1-3, written directly to `/dev/sda` with `dd` on
2026-08-29 and verified by reading the 649,068,544 bytes back and comparing
sha256 against the ISO (`3f66b2e1...92d1a1`). One partition, no Ventoy.

Ventoy was removed because it black-screened on this machine at boot. A
raw `dd` of the ISO is the method GParted itself documents, and it drops
the extra bootloader layer that was failing.

The other two ISOs live in `~/Downloads`, not on the stick:

| File | Use |
|---|---|
| `Win11_25H2_English_x64_v2.iso` | Step 2 — rewrite the stick with this |
| `nixos-minimal-26.05...iso` | Rescue / CLI alternative to GParted |

---

## If something goes wrong

Write the NixOS minimal ISO to the stick (same `dd`, it is in `~/Downloads`)
and boot that. Your partition table backup, if
you made one, is the fastest fix:

```sh
sfdisk /dev/nvme0n1 < /path/to/table.bak
```

To get at your data manually:

```sh
cryptsetup open /dev/nvme0n1p3 cryptroot
mount -o subvol=root /dev/mapper/cryptroot /mnt
```

Note: `p2` is a 36.25 GiB swap partition sitting between the ESP and p3, and
it is completely unused (0 B). Reclaiming it would free more space, but it is
not contiguous with the Windows partition, so it was left alone.
