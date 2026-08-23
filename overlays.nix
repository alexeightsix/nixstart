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
}
