# Mason, and anything else that downloads a prebuilt Linux binary.
#
# lua/plugins/mason.lua installs language servers as dynamically linked ELF
# binaries built against /lib64/ld-linux-x86-64.so.2, which does not exist on
# NixOS. Without this they install cleanly and then fail to execute. nix-ld
# provides the loader and a common set of libraries.
{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
      curl
      icu
      libgcc
    ];
  };
}
