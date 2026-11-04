#!/usr/bin/env bash
# Toggle easy boot: no LUKS passphrase, no greeter password.
#
#   scripts/easy-boot.sh toggle   on if it is off, off if it is on
#   scripts/easy-boot.sh on       enroll a key file, enable auto-login, rebuild
#   scripts/easy-boot.sh off      rebuild without it, then revoke the key
#   scripts/easy-boot.sh status
#
# Both rebuild with `apply.sh boot`, so the change applies on the next
# startup and the running session is left alone. See system/core/easy-boot.nix
# for what this does and what it costs.
set -euo pipefail

# The setuid sudo lives in /run/wrappers/bin, and not every launcher has it on
# PATH. vicinae's unit sets its own PATH without it, so from $mod+d `sudo`
# resolved to the bare /run/current-system/sw/bin/sudo, which refuses to run.
# apply.sh inherits this.
export PATH="/run/wrappers/bin:$PATH"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAG="$REPO/system/easy-boot-flag.nix"
KEY=/etc/secrets/initrd/cryptroot.key

# The existing disk passphrase, used once to authorise adding the key file, so
# `on` does not stop to ask for it. Kept outside the repository; without the
# file, cryptsetup asks for it instead.
PASSPHRASE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/easy-boot/passphrase"

step() { printf '\n\033[1;32m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

[ -f "$FLAG" ] || die "no $FLAG; this machine has not been set up for easy boot"

# The partition under the open mapping, so the UUID lives in one place only
# (hardware-configuration.nix).
DEV="$(sudo cryptsetup status cryptroot | awk '$1 == "device:" { print $2 }')"
[ -b "$DEV" ] || die "could not find the device behind /dev/mapper/cryptroot"

is_on() { grep -qE 'easyBoot\.enable = true;' "$FLAG"; }
set_flag() { sed -i -E "s/(easyBoot\.enable = )(true|false);/\1$1;/" "$FLAG"; }
key_works() { sudo test -f "$KEY" && sudo cryptsetup open --test-passphrase --key-file "$KEY" "$DEV" 2>/dev/null; }

MODE="${1:-status}"
if [ "$MODE" = toggle ]; then
    is_on && MODE=off || MODE=on
fi

case "$MODE" in
    on)
        if ! sudo test -f "$KEY"; then
            step "creating $KEY"
            sudo install -d -m 700 /etc/secrets/initrd
            sudo sh -c "umask 077; head -c 64 /dev/urandom > '$KEY'"
        fi
        if ! key_works; then
            step "adding the key file to $DEV"
            if [ -r "$PASSPHRASE_FILE" ]; then
                # printf, not cat: a trailing newline would become part of
                # the passphrase and fail to match.
                printf '%s' "$(cat "$PASSPHRASE_FILE")" \
                    | sudo cryptsetup luksAddKey --key-file=- "$DEV" "$KEY"
            else
                sudo cryptsetup luksAddKey "$DEV" "$KEY"
            fi
        fi
        set_flag true
        "$REPO/scripts/apply.sh" boot
        step "easy boot is ON from the next startup"
        ;;
    off)
        set_flag false
        # Rebuild first. If this fails, the key stays enrolled and the current
        # initrd still boots.
        "$REPO/scripts/apply.sh" boot
        if key_works; then
            step "revoking the key file's LUKS slot"
            sudo cryptsetup luksRemoveKey "$DEV" "$KEY"
        fi
        sudo rm -f "$KEY"
        step "easy boot is OFF from the next startup (passphrase + greeter again)"
        ;;
    status)
        is_on && echo "config:   on" || echo "config:   off"
        key_works && echo "key slot: enrolled" || echo "key slot: none"
        ;;
    *)
        echo "usage: $0 [toggle|on|off|status]" >&2
        exit 2
        ;;
esac
