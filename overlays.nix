# Packages this repository builds, layered onto nixpkgs.
#
# Everything the bootstrap stages fetched by hand — `cargo install`, a git
# clone into ~/.oh-my-zsh/themes, a font release unzipped into
# /usr/local/share — is a derivation here, pinned by the lockfile and rebuilt
# by `nixos-rebuild` like anything else.
inputs: final: prev: {
  fury-renegade-rgb = final.callPackage ./pkgs/fury-renegade-rgb { };
  dracula-zsh-theme = final.callPackage ./pkgs/dracula-zsh-theme { };
  weather-wallpaper = final.callPackage ./pkgs/weather-wallpaper {
    src = inputs.weather-wallpaper;
  };
  glow-rose-pine = final.callPackage ./pkgs/glow-rose-pine {
    src = inputs.glow-rose-pine;
  };

  # jk builds itself; this only lifts its package into the same namespace as
  # everything else so modules do not have to reach into `inputs`.
  jk = inputs.jk.packages.${prev.stdenv.hostPlatform.system}.default;
}
