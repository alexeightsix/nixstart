# nixstart

NixOS with this config, on a Dell XPS 13 9350.

## Install

1. Write the installer to a USB stick, from any Linux machine:

   ```sh
   scripts/install/install-iso.sh            # list the USB sticks it will accept
   scripts/install/install-iso.sh /dev/sdX   # download and write
   ```

2. Boot the laptop from the USB stick and get online. The install downloads
   everything, so it needs a network.

   - **Ethernet:** plug it in; it connects by itself.
   - **Wi‑Fi:** the minimal installer has no NetworkManager, so use `wpa_cli`:

     ```sh
     sudo systemctl start wpa_supplicant
     wpa_cli
     > add_network
     > set_network 0 ssid "your-network"
     > set_network 0 psk "your-password"
     > enable_network 0
     > quit
     ```

   Check with `ping -c 3 nixos.org`.

   Once installed, this config keeps Wi‑Fi off, so use Ethernet after the
   first boot (or `nmcli radio wifi on` for a one-off).

3. Then:

   ```sh
   nix-shell -p git
   git clone https://github.com/alexeightsix/nixstart
   cd nixstart
   sudo scripts/install/install.sh /dev/nvme0n1 --luks --swap 40G
   ```

   This erases the disk. Add `--dry-run` first to see the plan.

4. Reboot, log in as `alex` with password `changeme`, and run `passwd`.

5. Commit the generated `system/hardware/` files.

## Update

```sh
scripts/apply/apply.sh
```

Then reboot.
