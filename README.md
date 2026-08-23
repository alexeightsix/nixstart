# nixstart

NixOS for two machines and a test VM, ported from the `kickstart` bootstrap
scripts. Two layers, deliberately kept apart:

```
system/          what a machine is    — boot, hardware, daemons, the display server
home/            what a person has    — shell, git, i3, the terminal, toolchains
hosts/           one file per machine — the facts true of it and no other
profiles/        home without NixOS   — an account on a box this repo doesn't own
pkgs/            derivations for what the bootstrap scripts fetched by hand
lib/unfree.nix   the unfree allowlist, by name rather than a blanket allow
```

`system/` and `home/` never import each other. `system/home.nix` is the only
link and it runs one way: the system tells the home layer what the machine is,
never the reverse. That is what makes the second command below work at all.

```sh
sudo nixos-rebuild switch --flake .#desktop     # a machine this repo owns
home-manager switch --flake .#alex@headless     # an account, anywhere
```

The second replaces `link.sh --headless`. Why that flag existed is worth
remembering: before it, the desktop bootstrap and the Incus provisioning each
kept their own list of what to link, and they had already drifted — an instance
linked `tmux.conf` and the desktop did not. One module set, two profiles, no
second list to forget.

## Hosts

| | desktop | laptop | vm |
|---|---|---|---|
| hardware | Fury Renegade RGB | Dell XPS 13 9350 | Incus guest |
| i3 status bar | no battery | battery + warnings | no battery |
| docker / libvirt / incus | ✓ ✓ ✓ | ✓ — ✓ | ✓ — — |
| tailscale | ✓ | ✓ | — |
| displays | fixed `xrandr` | `autorandr` | — |

`laptop` is a **Core Ultra 7 258V (Lunar Lake), Arc 140V, 32GB soldered
LPDDR5X, Killer BE201**, and gets `system/hardware/xps13.nix`: the latest
kernel rather than LTS (Xe2, BE201 and the SOF audio topology all landed across
6.11–6.13), the `xe` DRM driver rather than `i915`, s2idle because the platform
has no S3, `fprintd`, and `power-profiles-daemon` over TLP.

No libvirt on the laptop — full VMs do not belong on something running off a
60W charger — but incus is there, because that is how work moves.

## Options

Everything is switched on by `nixstart.system.*` (`system/options.nix`) and
`nixstart.home.*` (`home/options.nix`). All modules are imported all the time
and each is inert until its option is set, so adding a machine never means
editing a module. A host file is a list of decisions:

```nix
nixstart.system = {
  user.name = "alex";
  user.initialPassword = "changeme";

  desktop.enable = true;
  apps.gui = true;
  tailscale = true;

  virtualisation = { docker = true; libvirt = true; incus = true; };
  hardware = { keychron = true; rgb = true; bluetooth = true; };
};
```

A few options live next to the module that owns them rather than in
`options.nix` — `virtualisation`, `tailscale`, `hardware.xps13`,
`snapshots.home`, `user.initialPassword`, `desktop.jk`, `neovim.linkConfig`,
`pi.linkConfig`.

## The two kinds of path

The one distinction this port has to get right.

- **`nixstart.home.dotfiles`** is a **store path**, from the `dotfiles` flake
  input. Files Nix reads at build time come from here: `tmux.conf`, `dunstrc`,
  the Ghostty shaders, the wallpapers. Pinned by the lockfile, reproducible,
  frozen until the next rebuild.
- **`nixstart.home.checkout`** is a **path on the machine**, referred to and
  never read. The trees edited far more often than the system is rebuilt live
  here: `dotfiles/nvim`, `dotfiles/pi`, `dotfiles/zsh/alias`. An edit takes
  effect on save.

Conflating the two is what makes a ported configuration feel worse than the
shell scripts it replaced.

The `dotfiles` input is a **path**, not a git URL, and deliberately:
`ghostty-shaders/` and `zsh/copyline.plugin.zsh` are untracked in the `dev-env`
remote, so a git input silently produces a configuration missing both. Commit
those and the URL in `flake.nix` can be swapped back. Meanwhile:

```sh
sudo nixos-rebuild switch --flake . --override-input dotfiles path:/home/alex/kickstart
```

## Neovim and Pi are not managed

Both are installed, not configured. No generated `init.lua`, no
`programs.neovim`, nothing written to `~/.config/nvim` or `~/.pi/agent`. What
Nix owns is the *environment* — compilers, language servers, formatters,
Node — which is the part that does not exist on a NixOS box unless something
puts it there.

Each has an opt-in escape hatch (`nixstart.neovim.linkConfig`,
`nixstart.pi.linkConfig`), both off by default.

`programs.nix-ld` is on for the same reason: Mason downloads prebuilt,
dynamically linked binaries that look for `/lib64/ld-linux-x86-64.so.2`, which
does not exist here. Without it they install cleanly and then fail to run — the
most common way a working Neovim setup appears broken after a port.

Pi is the sharper case. Its configuration is a live TypeScript project with its
own tests and Docusaurus site, and its runtime state (`auth.json`, sessions,
`models-store.json`) has to stay untracked in the same directory the tracked
files are linked into. A store path is read-only and cannot hold both halves.

## Packages built here

| | was |
|---|---|
| `jk` | a hand-built ELF at `~/.local/bin/jk` — would not run on NixOS at all |
| `glow-rose-pine` | replaces `pkgs.glow` for the `md` alias |
| `weather-wallpaper` | `go build` in `~/dev/archive`, driven by two crontab lines |
| `dracula-zsh-theme` | a `git clone` into `~/.oh-my-zsh/themes` |
| `fury-renegade-rgb` | `cargo install` into `~/.cargo/bin` |

The weather wallpaper's `@reboot` crontab entry polled `xset q` up to 150 times
waiting for an X server to exist. It is a systemd user timer now, and systemd
already knows when the graphical session started. The same applies to `jk`,
`vicinae` and `batsignal`.

## Things the port fixed rather than carried over

- `.gitconfig` called `!/usr/bin/gh` as its credential helper. There is no
  `/usr/bin/gh` here.
- `i3config` hardcoded `$HOME/kickstart/...` in six places, while `link.sh` and
  `common.sh` went to real trouble to derive every path.
- `i3config` exec'd `dex-autostart`, `xss-lock` and `i3lock`; no stage
  installed any of the three. They arrived as Fedora transitive dependencies.
- `dunstrc` was tracked and `link.sh` never linked it, so dunst had been
  running on built-in defaults.
- The Ghostty config named `bloom.glsl`, which was not in the repository.
- `scripts/xrandr.sh` was one commented-out line, so every machine ran an empty
  script at login.
- The battery block had no thresholds, so the bar never left its idle colour
  and nothing warned before the machine suspended.
- The tracked `i3config` said `wallpaper-2.png` while `~/.fehbg` — what
  actually ran — pointed at the weather wallpaper's output.
- Incus was running on the desktop and no stage installed it.
- Neither real host had a login password. An assertion now fails the build
  rather than producing an account that cannot log in.

## What is still a shell script

- `scripts/backup.sh` — mounts `/dev/sda1` and rsyncs the system to it. An
  operator action, not system state.
- `scripts/sync-dev.sh`, `scripts/ssh-dev-storage.sh` — remote operations. The
  host and password they read move to sops; the scripts stay.
- `dotfiles/zsh/alias/*` — more than half are shell functions with fzf
  pipelines in them, which Nix could only hold as opaque strings. The directory
  stays the source of truth and is sourced at runtime, so adding an alias still
  does not need a rebuild.

## Testing

`hosts/vm` is a throwaway Incus VM, installed from the official NixOS ISO the
same way a real machine would be. It runs the same modules, so what is tested
is the real thing.

```sh
incus init --empty --vm nixos-test --project nixos-test \
  -c limits.cpu=6 -c limits.memory=10GiB -c security.secureboot=false -d root,size=60GiB
incus config device add nixos-test iso disk --project nixos-test \
  source=/path/to/nixos-minimal.iso boot.priority=10
```

The ISO's boot menu is graphical; press `t` within the first ten seconds for
the text menu on the serial console, then `e` and append
`console=ttyS0,115200` to the `linux` line so `incus console` can drive it.

## Before the first switch

1. **Replace `hosts/*/hardware-configuration.nix`.** The files in the tree are
   placeholders that exist only so the flake evaluates. Use
   `nixos-generate-config --show-hardware-config` on each machine.
2. **Change the password.** Both real hosts set
   `user.initialPassword = "changeme"`, which is world-readable in the store.
   Run `passwd` after the first login, or add a `user-password` secret to
   `secrets/<hostname>.yaml` — that wins over `initialPassword` whenever it
   exists. `mkpasswd -m yescrypt` generates the hash.
3. **`pkgs/fury-renegade-rgb` still carries `lib.fakeHash`** for both its `src`
   and `cargoHash`; crates.io answered 403 to every request when this was
   written. Only the desktop builds it. Build once and paste in the two hashes
   the failure prints.
4. **Set the laptop's DPI** once `xrandr --query` says which panel it has. The
   9350 ships FHD+, QHD+ or 2.8K OLED, and the value for each is in
   `hosts/laptop/default.nix`.
5. `secrets/<hostname>.yaml` is optional — the sops module skips itself when
   the file is absent.
