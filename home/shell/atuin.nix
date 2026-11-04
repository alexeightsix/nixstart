# Shell history.
{ ... }:
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      style = "compact";
      show_preview = true;
      show_help = false;
      show_tabs = false;
      ai.enabled = true;
      ai.model = "max";
    };
  };
}
