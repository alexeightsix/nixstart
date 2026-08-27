# JETBRAINS MONO FONT
rm -rf /tmp/fonts
rm -rf /usr/local/share/fonts/jetbrainsmono
mkdir -p /usr/local/share/fonts/jetbrainsmono
wget -P /tmp/fonts https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip && \
unzip /tmp/fonts/JetBrainsMono.zip -d /usr/local/share/fonts/jetbrainsmono/ && \
rm -rf /tmp/fonts
