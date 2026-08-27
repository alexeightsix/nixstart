flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
flatpak install --user flathub com.discordapp.Discord -y
flatpak install --user flathub com.getpostman.Postman -y
flatpak install --user flathub com.slack.Slack -y
flatpak install --user flathub com.transmissionbt.Transmission -y
flatpak install --user flathub hu.irl.cameractrls -y
flatpak install --user flathub io.beekeeperstudio.Studio -y
flatpak install --user flathub md.obsidian.Obsidian -y
flatpak install --user flathub us.zoom.Zoom -y

sudo ln -sf $HOME/.local/share/flatpak/exports/bin/com.discordapp.Discord /usr/bin/discord
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/com.getpostman.Postman /usr/bin/postman
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/com.slack.Slack /usr/bin/slack
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/com.transmissionbt.Transmission /usr/bin/transmission
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/hu.irl.cameractrls /usr/bin/cameractrls
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/io.beekeeperstudio.Studio /usr/bin/beekeeper
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/md.obsidian.Obsidian /usr/bin/obsidian
sudo ln -sf $HOME/.local/share/flatpak/exports/bin/us.zoom.Zoom /usr/bin/zoom
