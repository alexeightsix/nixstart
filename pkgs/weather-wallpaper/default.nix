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
  dejavu_fonts,
}:
buildGoModule {
  pname = "weather-wallpaper";
  version = "0-unstable-2026-08-18";
  inherit src;

  # buildGoModule applies postPatch to the vendor derivation as well as the
  # build, so adding the font patch below changed this hash.
  vendorHash = "sha256-BIG+yEabnAs1lV2TxAiba+GvMSRXsIK5comKAilr+54=";

  nativeBuildInputs = [ makeWrapper ];

  # loadFont() searches four hardcoded FHS paths — Fedora's, Debian's, Arch's
  # and google-noto's — and `panic`s when it finds none. On NixOS none of them
  # exist, so the program aborted every run, ~/.cache/wallpaper-dynamic.jpg
  # was never written, and i3's `feh --bg-fill` at startup pointed at a file
  # that was not there: no wallpaper at all, which is the visible symptom.
  #
  # The font is a build input like any other, so the first path becomes a
  # store path and the search succeeds on its first try. --replace-fail so
  # that this stops the build rather than silently doing nothing if upstream
  # ever edits the list.
  postPatch = ''
    substituteInPlace main.go \
      --replace-fail '"/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf"' \
                     '"${dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf"'
  '';

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
