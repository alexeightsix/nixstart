if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

# DMENU SOUND ALIAS
ln -s /usr/bin/pavucontrol /usr/bin/sound
