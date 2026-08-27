#!/usr/bin/env bash
#
# link.sh — put this repository's configuration in place for the account that
# runs it.
#
#   link.sh              everything, desktop configuration included
#   link.sh --headless   only what applies without a display
#
# One list, two callers. bootstrap/stage-03.sh runs it on a workstation and the
# Incus provisioning runs it with --headless inside an instance; before this
# existed each kept its own list, and they had already drifted — an instance
# linked tmux.conf and the desktop did not.
#
# Idempotent, and safe to re-run: anything already at a destination that is not
# a symlink is moved aside to a timestamped backup rather than overwritten.
#
# Nothing here knows the account or the clone path. $DOTFILES comes from this
# file's own location, so it is correct wherever the repository was cloned and
# whoever is running it.
#
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KICKSTART="$(cd "$DOTFILES/.." && pwd)"

HEADLESS=0
case "${1:-}" in
    --headless) HEADLESS=1 ;;
    "") ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "link.sh: unknown option: $1" >&2; exit 2 ;;
esac

stamp() { date +%Y%m%d-%H%M%S; }

preserve() { # preserve <path> — move a real file or directory out of the way
    local dest="$1"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$dest.backup-$(stamp)"
        echo "    kept the previous $dest as $dest.backup-*"
    fi
}

link() { # link <path-in-repo> <destination>
    local src="$DOTFILES/$1" dest="$2"
    if [ ! -e "$src" ]; then
        echo "    skip $dest — $1 is not in the repository"
        return
    fi
    # When the configuration is unpacked straight into ~/.config — which is how
    # the Incus instances take it — some destinations are already the source.
    # Linking those to themselves would replace a real directory with a symlink
    # pointing at itself.
    if [ "$src" -ef "$dest" ] 2>/dev/null; then
        echo "    ok   $dest is already in place"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    preserve "$dest"
    ln -sfn "$src" "$dest"
    echo "    link $dest"
}

# For formats that have no variables of their own. A symlink would leave a
# literal $HOME in a file the application cannot expand — and flameshot and
# vicinae rewrite their config as you use them, which through a symlink writes
# straight back into the repository.
render() { # render <path-in-repo> <destination>
    local src="$DOTFILES/$1" dest="$2"
    if [ ! -e "$src" ]; then
        echo "    skip $dest — $1 is not in the repository"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    preserve "$dest"
    sed -e "s|\$DOTFILES|$DOTFILES|g" \
        -e "s|\$KICKSTART|$KICKSTART|g" \
        -e "s|\$HOME|$HOME|g" \
        "$src" > "$dest"
    echo "    render $dest"
}

echo "linking $DOTFILES into $HOME"

# ------------------------------------------------------------------ shared ---
# Everything that is as useful over ssh on a headless box as it is on a desktop.
link .zshrc      "$HOME/.zshrc"
link .gitconfig  "$HOME/.gitconfig"
link tmux.conf   "$HOME/.tmux.conf"
link nvim        "$HOME/.config/nvim"
link atuin.toml  "$HOME/.config/atuin/config.toml"

if [ $HEADLESS -eq 1 ]; then
    echo "  (--headless: skipping the desktop configuration)"
    exit 0
fi

# ----------------------------------------------------------------- desktop ---
link ghostty       "$HOME/.config/ghostty/config"
link lazydocker.yml "$HOME/.config/lazydocker/config.yml"
link i3config      "$HOME/.config/i3/config"

render flameshot.ini "$HOME/.config/flameshot/flameshot.ini"
render vicinae.json  "$HOME/.config/vicinae/settings.json"

# Pi: settings, keybindings, mcp.json, the theme, extensions and skills.
if [ -f "$DOTFILES/pi/link.sh" ]; then
    bash "$DOTFILES/pi/link.sh"
    link pi/pi-launcher "$HOME/.local/bin/pi"
fi

# burn lives in its own repository; this only puts it on PATH when it is there.
if [ -x "$HOME/dev/burn/burn" ]; then
    link_target="$HOME/.local/bin/burn"
    mkdir -p "$(dirname "$link_target")"
    ln -sfn "$HOME/dev/burn/burn" "$link_target"
    echo "    link $link_target"
fi
