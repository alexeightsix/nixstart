# stage-05 cloned dracula/zsh into /tmp and copied the theme plus its lib/ into
# ~/.oh-my-zsh/themes. oh-my-zsh's own directory is read-only on NixOS, so the
# theme becomes a custom-directory drop-in instead — see modules/home/shell/zsh.nix.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "dracula-zsh-theme";
  version = "0-unstable-2024-01-01";

  src = fetchFromGitHub {
    owner = "dracula";
    repo = "zsh";
    rev = "main";
    hash = lib.fakeHash;
  };

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/themes"
    cp dracula.zsh-theme "$out/themes/"
    cp -r lib "$out/themes/"
    runHook postInstall
  '';

  meta = {
    description = "Dracula theme for oh-my-zsh";
    homepage = "https://github.com/dracula/zsh";
    license = lib.licenses.mit;
  };
}
