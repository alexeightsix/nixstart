# Helpers shared by the home modules.
{ lib, ... }:
{
  # Some applications rewrite their own configuration as you use them
  # (flameshot, vicinae), and a read-only store path makes that write fail.
  # This seeds the file once, on activation, and then stays out of the way.
  mkSeededFile =
    { target, source }:
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${target}" ]; then
        run mkdir -p "$(dirname "${target}")"
        run install -m 0644 ${source} "${target}"
      fi
    '';
}
