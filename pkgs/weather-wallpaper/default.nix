# The weather wallpaper: the base image with the current temperature drawn in
# the top-right corner, refreshed on a schedule.
#
# Was a `go build` in a checkout under ~/dev/archive, with the resulting
# binary committed next to its source and driven by two crontab lines — one
# every minute, and an @reboot entry that polls `xset q` up to 150 times
# waiting for an X server to exist. Both of those problems go away here: the
# binary is a store path, and systemd already knows when the graphical session
# has started.
{
  lib,
  buildGoModule,
  src,
  makeWrapper,
  feh,
}:
buildGoModule {
  pname = "weather-wallpaper";
  version = "0-unstable-2026-08-18";
  inherit src;

  vendorHash = "sha256-fzv6pUV3AD4j7Y/bwW5TOS8IiTtSCY1uNVYNGqmghko=";

  nativeBuildInputs = [ makeWrapper ];

  # It shells out to feh to apply the result, so feh has to be on its PATH
  # rather than merely installed somewhere in the user's profile.
  postInstall = ''
    wrapProgram "$out/bin/wallpaper" --prefix PATH : ${lib.makeBinPath [ feh ]}
  '';

  meta = {
    description = "Wallpaper with the current temperature drawn on it";
    homepage = "https://github.com/upbeatdevelopment/wealther-wallpaper";
    mainProgram = "wallpaper";
  };
}
