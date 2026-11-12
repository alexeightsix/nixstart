# The Herdr desktop app, and the herdr-core server it drives.
#
# Upstream only ships `curl … /app/install.sh | sh`, which unpacks a prebuilt
# binary into ~/.local/share/herdr-app, writes a .desktop file by hand, and
# installs herdr-core into ~/.local/bin if none is there. Both are the same
# release tarballs here, pinned. Versions and hashes come from
# https://releases.herdr.dev/app/latest.json and .../core/latest.json.
#
# The TUI (`herdr`) is a separate program and is in nixpkgs already.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  libxcb,
  libxkbcommon,
  libGL,
  vulkan-loader,
  wayland,
}:
let
  # Statically linked, so nothing to patch. The app looks for it on PATH and
  # offers to download one into ~/.local/bin when it is missing; the wrapper
  # below makes sure it never has to.
  core = stdenv.mkDerivation rec {
    pname = "herdr-core";
    version = "0.1.20";

    src = fetchurl {
      url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-x86_64.tar.gz";
      hash = "sha256-rGuGiQxFGjdYRiCqpDi3G8DQvUMKLnwdfglfBSxBTnQ=";
    };
    sourceRoot = ".";

    installPhase = ''
      install -Dm755 herdr-core $out/bin/herdr-core
      ln -s herdr-core $out/bin/hc
    '';
  };
in
stdenv.mkDerivation rec {
  pname = "herdr-app";
  version = "0.1.15";

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${version}/herdr-app-linux-x86_64.tar.gz";
    hash = "sha256-+Z4eBL6CwOELL2nudAPKNDhvSA2SUR31hlr0cD52Vd0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];
  buildInputs = [
    libxcb
    libxkbcommon
    stdenv.cc.cc.lib
  ];

  # The same entry install.sh writes into ~/.local/share/applications.
  desktopItems = [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  # EGL, Vulkan and Wayland are dlopen'd rather than linked, so
  # autoPatchelfHook cannot see them; they go on LD_LIBRARY_PATH instead.
  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-app $out/libexec/herdr-app/herdr-app
    install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
    makeWrapper $out/libexec/herdr-app/herdr-app $out/bin/herdr-app \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          vulkan-loader
          wayland
          libxkbcommon
        ]
      } \
      --prefix PATH : ${core}/bin
    ln -s ${core}/bin/herdr-core ${core}/bin/hc -t $out/bin
    runHook postInstall
  '';

  passthru = { inherit core; };

  meta = {
    description = "Desktop app for terminals and coding agents that keep running";
    homepage = "https://herdr.dev";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "herdr-app";
  };
}
