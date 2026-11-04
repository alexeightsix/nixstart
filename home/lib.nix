# Helpers shared by the home modules.
{ lib, ... }:
{
  # Some applications rewrite their own configuration as you use them.
  # flameshot and vicinae both do, and link.sh had to `render` rather than
  # `link` them for exactly that reason: through a symlink, the application's
  # next write lands back in the repository.
  #
  # A store path makes that worse, not better — it is read-only, so the write
  # fails outright. This seeds the file once, on activation, and then stays
  # out of the way.
  mkSeededFile =
    { target, source }:
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${target}" ]; then
        run mkdir -p "$(dirname "${target}")"
        run install -m 0644 ${source} "${target}"
      fi
    '';
}
