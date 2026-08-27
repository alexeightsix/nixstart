#
# Sourced by the stage scripts. Nothing here is specific to a machine or an
# account: the repository locates itself from this file, and the account is
# whoever is running the installer.
#
# The stages used to spell out /home/alex everywhere, which meant the repo only
# worked when cloned to that one path by that one user. It is now also cloned
# into disposable Incus instances as `dev`, so every path is derived.
#

# The repository root, from this file rather than the caller's cwd — the stages
# are runnable as `bash bootstrap/stage-03.sh` or `cd bootstrap && bash ...`.
KICKSTART="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES="$KICKSTART/dotfiles"

# Who the install is *for*. Under sudo that is the invoking account, not root:
# a stage that runs as root still links configs into a human's home.
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
: "${TARGET_HOME:=$HOME}"

export KICKSTART DOTFILES TARGET_USER TARGET_HOME
