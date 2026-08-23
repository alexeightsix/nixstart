# stage-05 installed atuin with `bash <(curl ...)`, which put a binary in
# ~/.atuin/bin and an env file .zshrc then had to source conditionally,
# "only present when atuin came from its own installer".
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
