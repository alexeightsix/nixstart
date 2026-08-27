if [[ $EUID -eq 0 ]]; then
    echo "Running as root"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Every link and every rendered config lives in one place now, shared with the
# Incus provisioning so the two cannot drift apart. See dotfiles/link.sh.
bash "$DOTFILES/link.sh"

sudo npm install -g neovim
sudo chown -R "$(id -un):$(id -gn)" "$HOME"
