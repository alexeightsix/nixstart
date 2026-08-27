if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## SYSTEMD
systemctl enable --now crond.service
systemctl enable --now sshd

## VICINAE (per-user launcher daemon)
runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user enable --now vicinae.service

# DISABLE SPEAKER
touch /etc/modprobe.d/nobeep.conf && \
tee /etc/modprobe.d/nobeep.conf << END
blacklist pcspkr
blacklist snd_pcsp
END

# DOCKER
dnf -y install dnf-plugins-core && \
dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo && \
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
systemctl enable docker && \
systemctl start docker && \
usermod -aG docker "$TARGET_USER"
