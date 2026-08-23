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
  version = "0.1.0";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-QdB9iXsVuOCCj1iu9oaEaYDUiK0gdhhmdB/dFNAKvXc=";
  };

  cargoHash = "sha256-Irogq3Yjg3MSQWnMFOLsAt401AQVd6EGnDzYNXLZYLM=";

  meta = {
    description = "Control Kingston Fury Renegade RGB over i2c";
    license = lib.licenses.mit;
    mainProgram = "fury-renegade-rgb";
  };
}
