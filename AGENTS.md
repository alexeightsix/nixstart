# Notes for agents working in this repository

## New programs go in the launcher

Every new program added here must be reachable from the launcher: vicinae
on `$mod+d` (`home/desktop/wm/i3.nix`). Vicinae lists desktop entries from the
paths in `home/desktop/apps/vicinae.nix`, so a program with no `.desktop` file
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
  `home/desktop/audio/bluetooth-headphones.nix` does for `bt`.

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

## Rebuilding: use `agent-apply`

When a change needs a rebuild, do not run `nixos-rebuild` or the `rebuild`
alias in your own shell. Apply it only when the user asks you to; otherwise
stop and tell them it is ready. To apply:

    agent-apply           # switch (the default)
    agent-apply test      # live, leaving the boot menu alone

Why it is done this way (the long version is at the top of
`scripts/apply/agent-apply.sh`):

- **It outlives your terminal.** Activation can restart X, which kills every
  terminal on it, yours included, and a rebuild still running in one. The
  script runs the rebuild in a detached session that belongs to no terminal
  and follows its output from outside, so you still see the build.
- **It never waits on a password.** It relies on the NOPASSWD rule for
  `nixos-rebuild` in `system/core/users.nix`, and fails in one line instead
  of hanging if that rule is not active yet.
- **One at a time.** If an apply is already running it follows that one
  rather than starting a second rebuild against the same profile.

tmux is not installed on this machine. `agent-apply` carries its own copy for
the detached session, so do not reach for `tmux` directly.
