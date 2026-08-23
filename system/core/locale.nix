{ lib, ... }:
{
  time.timeZone = lib.mkDefault "America/Toronto";
  i18n.defaultLocale = lib.mkDefault "en_CA.UTF-8";
  console.keyMap = lib.mkDefault "us";
}
