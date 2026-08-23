# stage-07: hold the RAM RGB at zero.
#
# The old unit was written by `sudo tee` from an unquoted heredoc so that $HOME
# expanded as the file was created — the comment in stage-07 says as much. The
# ExecStart is a store path here, and the i2c group is declared rather than
# created by `groupadd` on a machine that may already have it.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.kickstart.system.hardware.rgb {
    users.groups.i2c = { };
    kickstart.system.user.extraGroups = [ "i2c" ];

    hardware.i2c.enable = true;
    environment.systemPackages = [ pkgs.i2c-tools ];

    systemd.services.rgb = {
      description = "Hold the RAM RGB at zero brightness";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe pkgs.fury-renegade-rgb} -b /dev/i2c-10 -2 -4 brightness --value 0";
      };
    };
  };
}
