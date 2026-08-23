# nixstart

The NixOS half of `kickstart`. Two layers, deliberately kept apart:

```
system/     what a machine is    — boot, hardware, daemons, the display server
home/       what a person has    — shell, git, i3, the terminal, toolchains
hosts/      one file per machine — the facts true of it and no other
profiles/   home without NixOS   — an account on a box this repo doesn't own
pkgs/       derivations for what the bootstrap scripts fetched by hand
lib/        the unfree allowlist
```

`system/` and `home/` do not import each other. `system/home.nix` is the only
link, and it runs one way: the system tells the home layer what the machine is,
never the reverse. That is what makes the second command below work.

```sh
sudo nixos-rebuild switch --flake .#desktop      # a machine this repo owns
home-manager switch --flake .#alex@headless      # an account, anywhere
```

The second replaces `link.sh --headless`. The reason that flag existed is worth
keeping in mind: before it, the desktop bootstrap and the Incus provisioning
each kept their own list of what to link, and they had already drifted — an
instance linked `tmux.conf` and the desktop did not. One module set, two
profiles, and no second list to forget.

## Options

Everything is turned on by `nixstart.system.*` (see `system/options.nix`) and
`nixstart.home.*` (see `home/options.nix`). A host file is a list of decisions:

```nix
kickstart.system = {
  desktop.enable = true;
  apps.gui = true;
  virtualisation.docker = true;
  hardware = { keychron = true; rgb = true; bluetooth = true; };
};
```

The modules are all imported all the time and each is inert until its option is
set, so `system/default.nix` never has to be edited to add a machine.

## The two kinds of path

The one distinction this port has to get right.

- **`kickstart.home.dotfiles`** is a **store path**, from the `dotfiles` flake
  input. Files Nix reads at build time come from here: `tmux.conf`, `dunstrc`,
  the Ghostty shaders, the wallpapers. Pinned by the lockfile, reproducible,
  and frozen until the next rebuild.
- **`kickstart.home.checkout`** is a **path on the machine**, referred to and
  never read. The trees that are edited far more often than the system is
  rebuilt live here: `dotfiles/nvim`, `dotfiles/pi`, `dotfiles/zsh/alias`. An
  edit takes effect on save.

Conflating the two is what makes a ported configuration feel worse than the
shell scripts it replaced. While iterating on the dotfiles themselves:

```sh
sudo nixos-rebuild switch --flake . --override-input dotfiles path:/home/alex/kickstart
```

## Neovim is not managed

`home/editor/neovim.nix` installs the editor and the compilers, language
servers and formatters its config expects to find on `PATH`. It does not
generate an `init.lua`, does not use `programs.neovim`, and does not write to
`~/.config/nvim`. `dotfiles/nvim` stays a lazy.nvim tree with its own
`lazy-lock.json`, edited in place.

`programs.nix-ld` is on for the same reason: Mason downloads prebuilt,
dynamically linked binaries that look for `/lib64/ld-linux-x86-64.so.2`, which
does not exist on NixOS. Without it they install cleanly and then fail to run —
the most common way a working Neovim setup appears broken after a port.

## What is still a shell script

Not everything should become Nix, and these did not:

- `scripts/backup.sh` — mounts `/dev/sda1` and rsyncs the system to it. An
  operator action, not system state.
- `scripts/sync-dev.sh`, `scripts/ssh-dev-storage.sh` — remote operations. The
  host and password they read move to sops (`system/core/secrets.nix`); the
  scripts stay.
- `dotfiles/zsh/alias/*` — half of these are shell functions with fzf pipelines
  in them. Nix could only hold them as opaque strings.
- `dotfiles/pi/link.sh` — it already solves the problem home-manager would, and
  solves it better here: Pi's runtime state (`auth.json`, sessions,
  `models-store.json`) has to stay untracked in the same directory the tracked
  files are linked into. A store path cannot hold both.

## Before the first switch

1. Replace `hosts/*/hardware-configuration.nix` with real output from
   `nixos-generate-config --show-hardware-config`. The files in the tree are
   placeholders that only exist so the flake evaluates.
2. `pkgs/fury-renegade-rgb` and `pkgs/dracula-zsh-theme` carry
   `lib.fakeHash`. Build once, take the hash from the failure, paste it in.
3. Create `secrets/<hostname>.yaml` with sops, or leave it out — the module
   is skipped when the file is absent.
