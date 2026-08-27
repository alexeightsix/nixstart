source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ZSH
# KEEP_ZSHRC stops the installer writing its own ~/.zshrc over the symlink
# link.sh puts there; CHSH and RUNZSH stop it changing the login shell and
# dropping into an interactive zsh in the middle of the run.
find "$HOME/.oh-my-zsh" -delete
KEEP_ZSHRC=yes CHSH=no RUNZSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# DRACULA
find /tmp/dracula -delete
git clone https://github.com/dracula/zsh.git /tmp/dracula
cp /tmp/dracula/dracula.zsh-theme "$HOME/.oh-my-zsh/themes/dracula.zsh-theme"
cp -rf /tmp/dracula/lib/ "$HOME/.oh-my-zsh/themes"

# ATUIN
bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)

# Last: both installers above write into ~/.zshrc and ~/.config, so anything
# they replaced is put back here rather than left broken until the next full
# bootstrap. link.sh is idempotent, so running it twice costs nothing.
bash "$DOTFILES/link.sh"
