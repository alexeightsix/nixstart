#!/bin/bash

# Device Info
VENDOR_ID="3434"
PRODUCT_ID="0223"
UDEV_RULE_FILE="/etc/udev/rules.d/99-keychron.rules"

# Check for root
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root:"
  echo "  sudo $0"
  exit 1
fi

# Write udev rule
echo "Creating udev rule for Keychron K2 Pro..."
cat <<EOF > "$UDEV_RULE_FILE"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", MODE="0666"
EOF

# Reload udev
echo "Reloading udev rules..."
udevadm control --reload
udevadm trigger

# Add user to plugdev group (optional)
if getent group plugdev >/dev/null; then
  echo "Adding user '$SUDO_USER' to 'plugdev' group..."
  usermod -aG plugdev "$SUDO_USER"
  echo "You may need to log out and back in for group changes to take effect."
fi

echo "Done. Please unplug and replug the device."
