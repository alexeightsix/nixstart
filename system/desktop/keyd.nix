# Escape as a navigation layer: hold it and h/j/k/l are Left/Down/Up/Right,
# tap it and it is still Escape.
#
# xkb cannot do this — Escape is not a modifier there, and caps:escape in
# desktop/x11.nix only renames a key. keyd sits below X at the evdev level,
# so the layer works in every application, on the TTYs, and on both the
# laptop keyboard and the Keychron.
#
# Caps Lock gets the same binding, since it is the Escape most reached for.
# keyd emits Escape for it itself, which leaves caps:escape in x11.nix as
# the fallback if this service is ever stopped.
#
# The one cost of overload(): a tap sends Escape on release rather than on
# press, because until the key comes up keyd cannot know whether it is a tap.
{
  ...
}:
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          esc = "overload(nav, esc)";
          capslock = "overload(nav, esc)";
        };
        nav = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
      };
    };
  };
}
