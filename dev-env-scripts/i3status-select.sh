#!/bin/bash
# Laptop or desktop status bar, chosen by whether this machine has a battery.
# The config path is derived from this script's own location, so the repo works
# wherever it is cloned.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"

if [ -d /sys/class/power_supply/BAT0 ]; then
    exec /usr/bin/i3status-rs "$DOTFILES/i3status.toml"
else
    exec /usr/bin/i3status-rs "$DOTFILES/i3status-desktop.toml"
fi
