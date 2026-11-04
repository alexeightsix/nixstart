# Notes for agents working in this repository

## New programs go in the launcher

Every new program added here must be reachable from the launcher: vicinae
on `$mod+d` (`home/desktop/i3.nix`). Vicinae lists desktop entries from the
paths in `home/desktop/vicinae.nix`, so a program with no `.desktop` file
does not appear in it. Check this every time you add a package:

- **GUI app from nixpkgs**: these usually ship their own entry. After the
  build, check that `share/applications/*.desktop` exists in the output
  (`ls $(nix build --no-link --print-out-paths …)/share/applications`).
  If it is missing, add one with `xdg.desktopEntries`.
- **Package built in `pkgs/`**: install an entry with `makeDesktopItem` and
  `copyDesktopItems`, plus an icon under `share/icons/hicolor`, the way
  `pkgs/herdr-app` does.
- **TUI program or script**: add an `xdg.desktopEntries.<name>` whose `exec`
  opens it in ghostty
  (`${lib.getExe config.programs.ghostty.package} -e …`), the way
  `home/desktop/bluetooth-headphones.nix` does for `bt`.

Skip this only for plain command-line tools that nobody launches on their
own (`ripgrep`, `jq`, or libraries pulled in for other packages). When
unsure, add the entry.

After applying the change, the entry should be under
`/etc/profiles/per-user/<user>/share/applications`.

## Restart vicinae after installing a program

Vicinae keeps its own index of applications, so a program installed while
it is running does not show up until it restarts. The `rebuild` alias
(`home/shell/aliases.nix`) already ends with a vicinae restart. If the change
was applied some other way and it installs a program, restart vicinae as the
last step:

    systemctl --user restart vicinae.service

Then check that the new entry appears.

## Rebuilding: use `rebuild` in a tmux session

When a change needs a rebuild, do not run `nixos-rebuild` in your own shell.
Open a detached tmux session and type the `rebuild` alias into it, but do
**not** press Enter. The user runs it:

    tmux new-session -d -s rebuild -c ~/nixstart zsh
    tmux send-keys -t rebuild 'rebuild'

Then stop and tell the user it is ready: they attach with
`tmux attach -t rebuild`, press Enter, and type the sudo password if asked.
Do not send `Enter` yourself.

Why it is done this way:

- **The tmux session** keeps the rebuild running if activation restarts X
  and kills the terminal it was started from.
- **`rebuild`** is a zsh alias, so it only exists in an interactive zsh.
  That is why the session starts `zsh` and the command is sent as keys
  instead of being passed to `tmux new-session` directly.

If a session named `rebuild` already exists, do not start a second one;
tell the user, since a rebuild may still be running there.
