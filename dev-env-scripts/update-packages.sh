#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as your normal user, not as root."
    exit 1
fi

sudo -v

# This repository
#
# First, because everything below is what the tracked configuration expects,
# and because a change pushed from an Incus instance reaches this machine no
# other way — nothing else here touches git.
#
# --ff-only so a desktop with local commits stops and says so rather than
# opening a merge in the middle of an update run. Re-links afterwards: a pull
# that adds a config file does nothing until something points at it.
KICKSTART="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Updating $KICKSTART"
if git -C "$KICKSTART" pull --ff-only; then
    bash "$KICKSTART/dotfiles/link.sh"
else
    echo "  !! could not fast-forward $KICKSTART — resolve it by hand" >&2
fi

# Base Packages
sudo dnf upgrade --refresh -y

# Atuin
atuin update

# Coding Agents
claude update
opencode upgrade
codex update
pi update --all
pi update --models

# Flatpak
flatpak update --user -y

# NPM Globals
npm update --global
sudo /usr/bin/npm update --global

# Rust Toolchain and Cargo Packages
rustup update
cargo install cargo-update
cargo install-update --all

# Go Tools
go install golang.org/x/tools/gopls@latest
go install github.com/jesseduffield/lazydocker@latest

# Oh My Zsh
ZSH="${ZSH:-$HOME/.oh-my-zsh}" zsh "$HOME/.oh-my-zsh/tools/upgrade.sh"

# Neovim Plugins
# The configuration itself is tracked by ~/kickstart and linked into ~/.config.
nvim --headless -c 'Lazy! sync' -c 'qa'

# App Images
for appimage in /opt/*.AppImage; do
    if [ -f "$appimage" ]; then
        echo "Updating $appimage..."
        chmod +x "$appimage"
        "$appimage" --appimage-update
    fi
done
