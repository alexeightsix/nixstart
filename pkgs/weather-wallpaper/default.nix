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

  # The temperature went in the top-right corner of the *image*, and the image
  # was then handed to `feh --bg-fill`, which with Xinerama scales and crops it
  # once per screen. On a layout whose screens are not all the same shape that
  # crop is different on each of them, so a corner that survives on one is cut
  # off on the next: 1920x1080 on the monitor, cropped 93px either side on the
  # 1680x1050 panel, which takes most of the number with it.
  #
  # The patch moves the decision from "the corner of the image" to "the corner
  # of each screen": it reads the layout from WALLPAPER_MONITORS as a list of X
  # geometries, draws the temperature once per screen, and switches feh to
  # --no-xinerama so the image it is given — already laid out for the whole
  # root window by home/desktop/wallpaper.nix — is applied as-is rather than
  # re-cropped. With the variable unset it draws one corner and runs plain
  # --bg-fill, exactly as before.
  #
  # Only the standard library is added, so vendorHash is unaffected.
  patches = [ ./multi-monitor.patch ];

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
