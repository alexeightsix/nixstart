# glow, with a built-in rose-pine style.
#
# The `md` alias is `glow`, and everything else on this desktop is Rose Pine —
# Ghostty's theme, the i3 bar, vicinae, Neovim. Upstream glow has no rose-pine
# style, so the fork replaces it rather than sitting alongside it.
{
  lib,
  buildGoModule,
  src,
}:
buildGoModule {
  pname = "glow-rose-pine";
  version = "2-unstable-2026-08-23";
  inherit src;

  vendorHash = "sha256-XQ/a1D/xqcx5+IjphN0LzGAV15S5exrL702679N/KTM=";

  # The upstream test suite reaches the network for the github/gitlab source
  # tests, which a sandboxed build has none of.
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Render markdown on the CLI, with a Rose Pine style";
    homepage = "https://github.com/upbeatdevelopment/glow-rose-pine";
    license = lib.licenses.mit;
    mainProgram = "glow";
  };
}
