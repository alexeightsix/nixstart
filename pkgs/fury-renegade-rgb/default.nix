# Turns the RAM RGB off (stage-07).
#
# Was: `cargo install fury-renegade-rgb` into ~/.cargo/bin, then a systemd unit
# with $HOME baked into ExecStart by an unquoted heredoc. The unit now points
# at a store path, so it does not break when the account is renamed or the home
# directory moves.
{
  lib,
  rustPlatform,
  fetchCrate,
}:
rustPlatform.buildRustPackage rec {
  pname = "fury-renegade-rgb";
  version = "0.1.3";

  # Both hashes are still placeholders: crates.io answered 403 to every
  # request from this network while the port was written, so they could not
  # be resolved. Build once on a machine that can reach it and paste in the
  # two hashes the failures print — nothing else here has to change.
  #
  # Only the desktop builds this (system/hardware/rgb.nix asserts as much), so
  # the laptop and the VM are unaffected by it being unresolved.
  src = fetchCrate {
    inherit pname version;
    hash = lib.fakeHash;
  };

  cargoHash = lib.fakeHash;

  meta = {
    description = "Control Kingston Fury Renegade RGB over i2c";
    license = lib.licenses.mit;
    mainProgram = "fury-renegade-rgb";
  };
}
