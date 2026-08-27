#!/usr/bin/env bash
# Build and apply this configuration.
#
#   scripts/apply.sh            stage for next boot (default, safest)
#   scripts/apply.sh switch     apply live
#   scripts/apply.sh test       apply live, but do not touch the boot menu
#
# `boot` is the default deliberately. Some changes here — anything that moves
# the system path, which includes the xdg-desktop-portal addition — make
# systemd restart display-manager, and that kills X, your session, and the
# terminal you are running this from. A `switch` from inside the desktop is how
# the 17:10 rebuild died with exit 101 halfway through activation. `boot`
# stages everything and lets the next startup apply it with nothing running.
#
# Run `switch` from a TTY (Ctrl+Alt+F2) if you want it live without rebooting.
set -euo pipefail

MODE="${1:-boot}"
case "$MODE" in
    boot|switch|test) ;;
    *) echo "usage: $0 [boot|switch|test]" >&2; exit 2 ;;
esac

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$(hostname)"

step() { printf '\n\033[1;32m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

cd "$REPO"

# --- the daemon ------------------------------------------------------------
# A failed activation can leave nix-daemon stopped, and then nothing builds.
# The socket pulls the service in on first connection, so starting it is enough.
if ! systemctl is-active --quiet nix-daemon.socket; then
    step "starting nix-daemon (it is not running)"
    sudo systemctl start nix-daemon.socket
fi

# --- tracked files ---------------------------------------------------------
# Flakes read the *git* tree, not the working directory: an untracked file is
# invisible to the build and the error it produces names a path rather than the
# reason. Staging is enough — nothing here commits for you.
if [ -n "$(git status --porcelain --untracked-files=all | grep '^??' || true)" ]; then
    step "staging untracked files so the flake can see them"
    git status --porcelain --untracked-files=all | grep '^??' | sed 's/^?? /    /'
    git add -A
fi

# --- the lockfile ----------------------------------------------------------
# Only inputs that are missing entirely; this never silently moves the others.
for input in $(grep -oE '^\s{4}[a-z][a-z-]+ = \{' flake.nix | tr -d ' ={' || true); do
    if ! grep -q "\"$input\": {" flake.lock; then
        step "adding missing flake input: $input"
        nix flake update "$input"
        git add flake.lock
    fi
done

# --- build -----------------------------------------------------------------
# Separately from activating, so a build error costs nothing and never leaves a
# half-applied system.
step "building $HOST"
nix build --no-link ".#nixosConfigurations.$HOST.config.system.build.toplevel"
built="$(nix path-info ".#nixosConfigurations.$HOST.config.system.build.toplevel")"
echo "    $built"

if [ "$built" = "$(readlink -f /run/current-system)" ]; then
    step "already running this configuration — nothing to apply"
    exit 0
fi

# --- apply -----------------------------------------------------------------
step "applying ($MODE)"
sudo nixos-rebuild "$MODE" --flake ".#$HOST"

case "$MODE" in
    boot)
        step "staged for next boot"
        warn "Nothing has changed on the running system yet. Reboot to apply:"
        warn "    sudo reboot"
        ;;
    switch|test)
        step "applied"
        # nixos-rebuild does not touch the running X session, so user units
        # carrying new definitions have to be told.
        warn "Reloading user services..."
        systemctl --user daemon-reload || true
        systemctl --user restart weather-wallpaper.service 2>/dev/null || true
        systemctl --user start display-dock.service display-dock-watch.service 2>/dev/null || true
        i3-msg restart >/dev/null 2>&1 || true
        warn "Done. If Ctrl+; still fails, log out and back in — the portal is a"
        warn "system service and the session needs to pick it up."
        ;;
esac
