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
| incus              | ✓       | ✓      | —  |
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
