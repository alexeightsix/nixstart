# Easy boot: power on and land on the desktop, with no LUKS passphrase and no
# greeter password. Toggled with `scripts/boot/easy-boot.sh on|off`, which flips
# system/boot/easy-boot-flag.nix and does the parts that cannot live in Nix.
#
# The disk is not decrypted. Decrypting and re-encrypting the volume in place takes hours
# each way, which is not something you can switch on and off. Instead, a random
# key file gets added as a second LUKS keyslot and is baked into the initrd,
# which the initrd then uses to open cryptroot by itself. The passphrase slot
# stays as it is.
#
# Be plain about what that costs: the initrd sits unencrypted on the ESP, so
# while this is on, anyone holding the laptop holds the key. In effect the
# disk is unencrypted. Turning it off rebuilds without the key and *removes the
# keyslot*, so copies left in older generations' initrds on /boot stop working.
#
# The screen still locks on idle (xss-lock) and still asks for the account
# password. This only skips the two prompts at boot.
#
# TPM2 unlock (systemd-cryptenroll) would be tidier, since the key would never
# touch the disk. The key file is the simpler thing to toggle.
{ config, lib, ... }:
let
  cfg = config.nixstart.system;
in
{
  options.nixstart.system.easyBoot.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Unlock cryptroot from a key file in the initrd and auto-login the user.
      Use scripts/boot/easy-boot.sh to flip it: that script also creates and
      enrolls the key, and revokes it again when you turn this off.
    '';
  };

  # Outside the initrd: root-only, and enrolled by scripts/boot/easy-boot.sh. It has
  # to exist before the rebuild, because the bootloader install copies it into
  # each initrd it writes.
  options.nixstart.system.easyBoot.keyFile = lib.mkOption {
    type = lib.types.str;
    default = "/etc/secrets/initrd/cryptroot.key";
    readOnly = true;
    description = "Where the LUKS key file lives on the running system.";
  };

  config = lib.mkIf cfg.easyBoot.enable {
    boot.initrd.secrets."/cryptroot.key" = cfg.easyBoot.keyFile;

    # No fallbackToPassword: the initrd is systemd stage 1 (nixpkgs' default),
    # where asking for the passphrase if the key is missing or revoked is
    # built in, and setting it is an assertion failure.
    boot.initrd.luks.devices."cryptroot".keyFile = "/cryptroot.key";

    services.displayManager.autoLogin = {
      enable = true;
      user = cfg.user.name;
    };
  };
}
