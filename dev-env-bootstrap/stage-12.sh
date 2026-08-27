sudo curl -o /etc/yum.repos.d/beekeeper-studio.repo https://rpm.beekeeperstudio.io/beekeeper-studio.repo
sudo rpm --import https://rpm.beekeeperstudio.io/beekeeper.key
dnf repolist
sudo dnf install beekeeper-studio

# why is this running
curl -fsSL https://raw.githubusercontent.com/pranshuparmar/witr/main/install.sh | bash
