# Mason, and anything else that downloads a prebuilt Linux binary.
#
# lua/plugins/mason.lua installs language servers as dynamically linked ELF
# binaries built against /lib64/ld-linux-x86-64.so.2, which does not exist on
# NixOS. Without this they install cleanly and then fail to execute — the
# single most common way a working Neovim setup appears broken after a port.
#
# nix-ld provides the loader and a common set of libraries, so Mason keeps
# working exactly as it does on Fedora. The language servers in
# modules/home/editor/neovim.nix are the alternative, not the replacement:
# lsp.nix already separates "servers Mason downloads" from "servers that ship
# with the language's own toolchain", and either half can win.
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
