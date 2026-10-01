# nixstart

NixOS for a Dell XPS 13 9350. `nixosConfigurations.laptop` is the only host.

## Setting up a new machine

### 1. Write an installer USB

From a machine you already have:

```sh
scripts/install-iso.sh               # list the devices it will accept
scripts/install-iso.sh /dev/sdX      # download, verify, write
```

Removable, unmounted devices only, and it makes you type the device name back.

### 2. Add a host, if it is not the laptop

`hosts/<name>/default.nix` holds the facts true of that machine and nothing
else — every module is inert until an option turns it on, so copy
`hosts/laptop/default.nix` and delete what does not apply. Then register it:

```nix
# flake.nix
nixosConfigurations = {
  laptop = mkHost { hostname = "laptop"; };
  <name> = mkHost { hostname = "<name>"; };
};
```

The installer writes `hardware-configuration.nix` for you in step 3.

### 3. Install

Boot the USB on the target, get this repo onto it, then:

```sh
scripts/install.sh <host> /dev/nvme0n1 --dry-run          # print the plan
scripts/install.sh <host> /dev/nvme0n1                    # plain
scripts/install.sh <host> /dev/nvme0n1 --luks --swap 40G  # encrypted, hibernate
```

btrfs with subvolumes — 1GiB vfat ESP, optional swap, then `@` `@home` `@nix`
`@log` — because `snapshots.home` needs `/home` to be its own subvolume.

It generates `hosts/<host>/hardware-configuration.nix` and a `filesystems.nix`
with by-label devices and the LUKS UUID, adds the import, and runs
`nixos-install`. Commit both files afterwards.

`--keep-home` reuses an existing `@home` instead of formatting it; check that
uid 1000 still owns it. `--dry-run` stops before touching the disk.

### 4. First boot

1. Log in with `user.initialPassword` from the host file (`"changeme"`) and run
   `passwd`. To skip the placeholder entirely, put a `user-password` secret in
   `secrets/<hostname>.yaml` — sops wins over the option whenever it exists.
2. Set `nixstart.home.desktop.dpi` once `xrandr --query` says which panel the
   machine has. It defaults to null, which is 96dpi.
3. Rebuild.

## Rebuilding

```sh
scripts/apply.sh            # stage for the next boot — the default
scripts/apply.sh switch     # apply live
scripts/apply.sh test       # apply live, leave the boot menu alone
```

`boot` is the default because anything that moves the system path restarts
display-manager, which kills X and the terminal you ran it from. Use `switch`
from a TTY if you want it live without rebooting.

## Updating

```sh
update          # move flake.lock, then rebuild
sync-nix        # update/rebuild, pi update --extensions, then collect generations older than 30d
bump-ghostty    # move the pinned ghostty revision to current main
```

Shell aliases, defined in `home/shell/aliases.nix`. `sync-nix` runs
`pi update --extensions` as the normal user after a successful rebuild and
before garbage collection. Each step must succeed before the next runs.
Nix still owns the Pi binary; this extra step updates its user-managed packages.

`nix flake update` moves every input except ghostty, which is pinned to an
explicit revision in `flake.nix` precisely so the sweep leaves it alone —
tracking a development branch is a choice, not something a routine update
should make on your behalf. `bump-ghostty` rewrites that one line and stops;
building it is still a separate, deliberate `sync-nix`.

## Development toolchains

The laptop enables Python through `nixstart.home.languages` in
`hosts/laptop/default.nix`. The shared `lib/dev-env.nix` definition installs
`python3` and `uv`; Python 3 is available on the user PATH after rebuilding.

## Changelog

### 2026-09-10 — Python and Pi package maintenance

**Why:** Python 3 is needed outside a development shell, and updating the Nix
lockfile does not update Pi's separately installed extension packages.

- **README** — the laptop includes Python 3 and uv; `sync-nix` updates Pi packages
  after rebuilding and before garbage collection, without self-updating Pi.
