# The weather wallpaper: the base image with the current temperature drawn in
# the top-right corner, refreshed on a schedule.
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

  # multi-monitor.patch draws the temperature in the corner of each screen
  # (from WALLPAPER_MONITORS, a list of X geometries) and runs feh with
  # --no-xinerama, since feh's per-screen crop cut the number off on screens
  # of a different shape. Unset, it behaves as upstream.
  #
  # robustness.patch, written against the first (order matters):
  #   - checks Open-Meteo's HTTP status, whose error JSON otherwise decodes
  #     to a plausible-looking "0";
  #   - image.Decode rather than jpeg.Decode, so .png works;
  #   - WALLPAPER_TEXT_COLOR / WALLPAPER_SHADOW_COLOR, defaulting to
  #     white-on-black.
  #
  # Both use only the standard library, so vendorHash is unaffected.
  patches = [
    ./multi-monitor.patch
    ./robustness.patch
  ];

  # loadFont() searches hardcoded FHS paths and panics when none exist, which
  # on NixOS is always. Point the first one at the store; --replace-fail so an
  # upstream edit breaks the build rather than silently doing nothing.
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
