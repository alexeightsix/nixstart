# One file per alias, named after it, under the dotfiles checkout's zsh/alias/.
#
# The convention is deliberate — "a name you cannot grep for by filename is a
# name you forget you defined" — and more than half of those files are shell
# functions with fzf pipelines in them, which Nix could only hold as opaque
# strings. So the directory stays the source of truth and is sourced at
# runtime. What moves here is the handful whose *meaning* changed on NixOS.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.kickstart.home;
in
{
  programs.zsh.initContent = lib.mkOrder 550 ''
    for alias_file in ${cfg.checkout}/dotfiles/zsh/alias/*(N); do
      source "$alias_file"
    done
    unset alias_file
  '';

  programs.zsh.shellAliases = {
    # `dnf` was aliased to take a snapper snapshot and then run dnf, because a
    # Fedora package transaction cannot be undone. Both halves are one command
    # here, and its rollback is a boot menu entry.
    rebuild = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/kickstart-nix#$(hostname)";
    rebuild-test = "sudo nixos-rebuild test --flake ${config.home.homeDirectory}/kickstart-nix#$(hostname)";
    generations = "nixos-rebuild list-generations";

    # scripts/update-packages.sh ran nine updaters in sequence — dnf, atuin,
    # claude, opencode, codex, pi, flatpak, npm -g, rustup, cargo-update, go
    # install, oh-my-zsh, lazy.nvim — each with its own idea of "current".
    # One lockfile moves now.
    update = "nix flake update --flake ${config.home.homeDirectory}/kickstart-nix && rebuild";

    # `zsh` opened ~/.zshrc and re-sourced it. That file is a store path now,
    # so the thing to edit is the module that generates it.
    zsh = "nvim ${config.home.homeDirectory}/kickstart-nix/home/shell/zsh.nix";
  };

  # The binaries the alias files shell out to. `ls` is eza, `md` is glow, `lg`
  # is lazygit, `or`/`pr` are gh, `ff` needs fd, `dff`/`gc`/`gcm`/`gr` need fzf.
  home.packages = with pkgs; [
    eza
    fd
    ripgrep
    fzf
    glow
    lazygit
    gh
    delta
    vhs
  ];
}
