# nixstart

NixOS for a desktop, an XPS 13, and a throwaway VM.

```
system/     what a machine is   — boot, hardware, daemons, X
home/       what a person has   — shell, git, i3, terminal, toolchains
hosts/      one file per machine
profiles/   home without NixOS  — an account on a box this repo doesn't own
pkgs/       jk, glow-rose-pine, weather-wallpaper, dracula-zsh-theme, fury-renegade-rgb
```

```sh
sudo nixos-rebuild switch --flake .#desktop     # a machine this repo owns
home-manager switch --flake .#alex@headless     # an account, anywhere
```

`system/` and `home/` never import each other; `system/home.nix` is the one
link and runs one way. `home/` reads only `nixstart.home.*`, which is why the
second command works at all.

## Hosts

|                    | desktop | laptop | vm |
|--------------------|---------|--------|----|
| battery in the bar | —       | ✓      | —  |
| docker             | ✓       | ✓      | ✓  |
| libvirt            | ✓       | —      | —  |
| incus              | ✓       | —      | —  |
| tailscale          | ✓       | ✓      | —  |
| /home snapshots    | ✓       | ✓      | ✓  |

`laptop` is a Dell XPS 13 9350 — Lunar Lake, Arc 140V, Killer BE201. See
`system/hardware/xps13.nix`.

## Options

`nixstart.system.*` (`system/options.nix`) and `nixstart.home.*`
(`home/options.nix`). Every module is always imported and inert until its
option is set, so adding a machine never means editing a module.

```nix
nixstart.system = {
  desktop.enable = true;
  apps.gui = true;
  tailscale = true;
  virtualisation = { docker = true; libvirt = true; incus = true; };
  hardware = { keychron = true; rgb = true; bluetooth = true; };
};
```

A few options live beside the module that owns them rather than in
`options.nix`: `virtualisation`, `tailscale`, `hardware.xps13`,
`snapshots.home`, `user.initialPassword`, `desktop.jk`, `neovim.linkConfig`,
`pi.linkConfig`.

## Two kinds of path

- `nixstart.home.dotfiles` — a **store path** from the `dotfiles` input. What
  Nix reads at build time: `tmux.conf`, `dunstrc`, the Ghostty shaders, the
  wallpapers. Pinned, frozen until the next rebuild.
- `nixstart.home.checkout` — a **path on the machine**, never read. What is
  edited far more often than the system is rebuilt: `nvim`, `pi`, `zsh/alias`.
  Edits take effect on save.

## Dev environment

`lib/dev-env.nix` is a plain function, not a module, so everything can use it:

| consumer | how |
|----------|-----|
| desktop / laptop | `home/dev/toolchains.nix` → `home.packages` |
| micro VM | `nixosModules.devEnv` → `environment.systemPackages` |
| dev shell | `lib/dev-shell.nix` → `mkShell` |
| anything else | `nixstart.lib.devEnv` |

Tiers (`base`, `toolchains`, `agentPackages`, `databasePackages`) are separate
so a VM running one agent takes `base ++ agents ++ one language`.

```sh
nix develop .#agent    # agents + go/node — what agents are started in
nix develop            # everything, by hand
nix develop .#node     # one language
nix develop .#nix      # working on this repo
```

`nix develop` gives you bash with no shell config, so `lib/dev-shell.nix`
generates the rc files as store paths and points zsh at them with `ZDOTDIR`,
then execs zsh. Nothing is written to the real home directory, so it is safe
on a machine whose shell setup you do not want touched — including one that is
not NixOS. Aliases are sourced at runtime, so adding one needs no rebuild.

## Agent VMs

`profiles/agent-vm.nix` — VM-technology agnostic; works under microvm.nix, an
Incus VM, or plain qemu.

```nix
{
  imports = [ nixstart.nixosModules.agentVm ];
  networking.hostName = "agent-01";
  nixstart.devEnv.languages = [ "node" ];
  nixstart.agentVm.authorizedKeys = [ "ssh-ed25519 AAAA..." ];
}
```

Keys only, no account password, no X, shell opens in `/workspace`, daily
`nix-gc --delete-older-than 3d` so a disposable image does not grow into its
own disk.

## Neovim and Pi are unmanaged

Installed, not configured. No generated `init.lua`, no `programs.neovim`,
nothing written to `~/.config/nvim` or `~/.pi/agent`. Nix owns the environment
— compilers, language servers, formatters — not the config. Opt in with
`nixstart.neovim.linkConfig` / `nixstart.pi.linkConfig`.

`programs.nix-ld` is on so Mason's prebuilt binaries still run.

## Snapshots

`/home` only. The system is a generation and rolls back from the boot menu;
`/home` is the part that doesn't. Hourly snapper timeline, 10 hourly / 10 daily
/ 4 weekly / 6 monthly / 2 yearly, tunable via `snapshots.limits`. Stops at 50%
used or 20% free.

`/home` must be its own btrfs subvolume. `snapper-home-subvolume.service`
creates `/home/.snapshots`; nothing else does.

No qgroups. `SPACE_LIMIT` would need them, and they are the most reliable way
to make a btrfs filesystem stall — every delete walks the quota tree.
`FREE_LIMIT` plus the retention counts bound the space without them. Cleanup
runs at idle IO and CPU priority so a pass can never be what makes the desktop
stutter, and both timers are jittered off the hour.

Disk is bounded elsewhere too: `min-free`/`max-free` make the Nix daemon
collect on its own below 5 GiB, weekly `nix-optimise` hard-links duplicates,
journald is capped at 2 GB, and `/tmp` is cleared on boot.

## Before the first switch

1. Replace `hosts/*/hardware-configuration.nix` — they are placeholders that
   exist only so the flake evaluates.
2. Change `user.initialPassword` (`"changeme"`), or add a `user-password`
   secret to `secrets/<hostname>.yaml`, which wins over it.
3. `pkgs/fury-renegade-rgb` carries `lib.fakeHash` for `src` and `cargoHash`.
   Desktop only. Build once and paste in what the failure prints.
4. Set the laptop's `dpi` once `xrandr --query` says which panel it has.
5. The `dotfiles` input is a local path, so this flake only evaluates on a
   machine that has that checkout. Point it at a git URL to change that.
