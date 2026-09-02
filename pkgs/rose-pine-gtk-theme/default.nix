# Rose Pine for GTK.
#
# nixpkgs carried `rose-pine-gtk-theme` and removed it: the derivation
# depended on gtk-engine-murrine, which went when GTK 2 did. Only the theme's
# gtk-2.0 half ever needed murrine and nothing on this desktop is a GTK 2
# application, so this is the same upstream repository built without it.
#
# One variant is installed, not the whole matrix. Upstream ships nine accent
# colours across light and dark, standard and compact — thirty-six directories
# of assets — and the desktop uses one: the base Rose Pine palette, dark, the
# same one Ghostty's `theme = "Rose Pine"` and vicinae's `theme.dark.name`
# already name. The installed theme is called `Rosepine-Dark`, which is what
# home/desktop/gtk.nix has to ask for.
{
  lib,
  stdenvNoCC,
  sassc,
  src,
}:
stdenvNoCC.mkDerivation {
  pname = "rose-pine-gtk-theme";
  version = "0-unstable-2025-10-23";
  inherit src;

  nativeBuildInputs = [ sassc ];

  dontConfigure = true;
  dontBuild = true;

  # install.sh writes to $HOME/.themes when it is not root and shells out to
  # `gnome-shell --version` to pick a shell stylesheet; the sandbox has no
  # home and no gnome-shell, and the script's own fallback handles the latter.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/themes
    HOME=$TMPDIR bash themes/install.sh \
      --dest $out/share/themes \
      --name Rosepine \
      --theme default \
      --color dark \
      --size standard

    runHook postInstall
  '';

  meta = {
    description = "Rose Pine GTK 3/4 theme, without the GTK 2 murrine dependency";
    homepage = "https://github.com/Fausto-Korpsvart/Rose-Pine-GTK-Theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
