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

  # Same for witr, which also builds itself.
  #
  # Its checkPhase does not survive a Linux sandbox, so the tests are off.
  # Both failures are in the harness rather than the program — every
  # `Building subPackage` step passes and the binary is fine:
  #
  #   internal/launchd   launchd is macOS-only, so on Linux the package has no
  #                      eligible files at all and `go test ./...` fails at
  #                      setup with "build constraints exclude all Go files".
  #   internal/proc      TestGetLockedFilesFindsHeldLock asserts that a lock it
  #                      just took shows up in /proc; inside the sandbox it
  #                      does not.
  #
  # Narrower options do not cover both: -skip takes a test name, and the
  # launchd failure is a whole package failing to configure, which has no test
  # name to skip. Upstream would have to fix the filter in its own flake.
  witr = (inputs.witr.packages.${prev.stdenv.hostPlatform.system}.default).overrideAttrs (_: {
    doCheck = false;
  });

}
