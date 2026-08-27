# dev-env bootstrap (historical)

The staged setup scripts from the Fedora machine this configuration was ported
from — `github.com/alexeightsix/dev-env`, `bootstrap/`. They are `dnf`, `copr`,
`rustup | sh` and `curl | bash`, so none of them can run on NixOS and none of
them are referenced by anything that builds.

They are kept because the modules cite them constantly: `system/desktop/fonts.nix`
opens "stage-11 downloaded a JetBrainsMono Nerd Font release zip", `system/core/nix.nix`
explains what `scripts/update-packages.sh` used to do, and so on throughout. Those
comments are the record of *why* a module is shaped the way it is, and they point
here. Deleting this directory turns every one of them into a dangling reference.

Nothing here should ever be run. What each stage did now lives in:

| stage | what it did                        | where it lives now                    |
|-------|------------------------------------|---------------------------------------|
| 01    | dnf repos + the bulk package list  | `system/desktop/apps.nix`, `lib/dev-env.nix` |
| 02    | enable crond, sshd, vicinae        | `system/services/openssh.nix`, `home/desktop/vicinae.nix` |
| 03    | run dotfiles/link.sh, npm neovim   | the `home/` modules; `home/editor/neovim.nix` |
| 04    | Flathub + eight flatpaks           | `system/desktop/flatpak.nix` (off by default) |
| 05    | zsh, oh-my-zsh, dracula, atuin     | `home/shell/zsh.nix`, `home/shell/atuin.nix` |
| 06    | rustup                             | `lib/dev-env.nix`                     |
| 07    | turn off RGB                       | `system/hardware/rgb.nix`             |
| 08    | Nix daemon + SELinux note          | the OS itself                         |
| 09    | Keychron udev rule + plugdev       | `system/hardware/keychron.nix`        |
| 10    | PHP/composer via remi              | `lib/dev-env.nix`                     |
| 11    | JetBrainsMono Nerd Font zip        | `system/desktop/fonts.nix`            |
| 12    | beekeeper-studio, witr             | `system/desktop/apps.nix` (witr not ported) |
| 14    | pavucontrol symlinked as `sound`   | `system/desktop/audio.nix`            |
| 15    | `curl | bash` for claude           | `home/dev/agents.nix`                 |
