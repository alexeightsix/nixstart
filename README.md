# nixstart

NixOS with this config, on a Dell XPS 13 9350.

## Install

1. Write the installer to a USB stick, from any Linux machine:

   ```sh
   scripts/install-iso.sh            # list the USB sticks it will accept
   scripts/install-iso.sh /dev/sdX   # download and write
   ```

2. Boot the laptop from the USB stick, then:

   ```sh
   nix-shell -p git
   git clone https://github.com/alexeightsix/nixstart
   cd nixstart
   sudo scripts/install.sh /dev/nvme0n1 --luks --swap 40G
   ```

   This erases the disk. Add `--dry-run` first to see the plan.

3. Reboot, log in as `alex` with password `changeme`, and run `passwd`.

4. Commit the generated `system/hardware/` files.

## Update

```sh
scripts/apply.sh
```

Then reboot.
