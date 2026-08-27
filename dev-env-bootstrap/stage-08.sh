# NixOS Requres SELinux to be disabled
# This file controls the state of SELinux on the system.
# /etc/selinux/config
# SELINUX= disabled
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
