if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf copr enable @go-sig/golang-rawhide -y && \
dnf copr enable atim/i3status-rust -y && \
dnf copr enable pgdev/ghostty && \
dnf copr enable quadratech188/vicinae -y && \

dnf update

dnf install \
  arandr \
  blueman \
  blueprint-compiler \
  bluez \
  bluez-tools \
  btop \
  btrfs-assistant \
  cmake \
  compat-lua \
  cronie \
  cronie-anacron \
  dnf-plugins-core \
  fastfetch \
  fd-find \
  feh \
  filezilla \
  firefox \
  flameshot \
  flatpak \
  fzf \
  gettext \
  gh \
  ghostty \
  gimp \
  git \
  git-delta \
  gnome-tweaks \
  gnome-system-monitor \
  golang \
  golangci-lint \
  gparted \
  gpick \
  gtk4-devel \
  i3status-rust \
  jq \
  libadwaita-devel \
  libvirt \
  luarocks \
  make \
  mariadb \
  ncdu \
  neovim \
  nmap \
  nodejs \
  npm \
  picom \
  piper \
  postgresql \
  python3 \
  qemu \
  rclone \
  ripgrep \
  rsync \
  snapper \
  telnet \
  tmux \
  vicinae \
  virt-manager \
  vlc \
  xclip \
  zoxide \
  zsh \
  xfce4-power-manager

dnf remove ghostscript plocate

# lazydocker - build latest from source (the atim/lazydocker COPR lags upstream)
# GOBIN puts it in /usr/local/bin (on PATH) instead of the default ~/go/bin
GOBIN=/usr/local/bin go install github.com/jesseduffield/lazydocker@latest

cd /tmp
wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm 
dnf install ./google-chrome-stable_current_x86_64.rpm
rm google-chrome-stable_current_x86_64.rpm
