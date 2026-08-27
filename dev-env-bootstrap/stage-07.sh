source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# TURN OFF RGB
cargo install fury-renegade-rgb
sudo groupadd i2c
sudo usermod -aG i2c "$(id -un)"
sudo touch /etc/systemd/system/rgb.service
# The heredoc is unquoted on purpose: systemd does not expand $HOME in
# ExecStart, so the path has to be resolved here, as the unit is written.
sudo tee /etc/systemd/system/rgb.service << END
[Unit]
Description=Disable RGB

[Service]
ExecStart=$HOME/.cargo/bin/fury-renegade-rgb -b /dev/i2c-10 -2 -4 brightness --value 0

[Install]
WantedBy=multi-user.target
END
sudo chmod a+x "$HOME/.cargo/bin/fury-renegade-rgb"
systemctl enable rgb.service
