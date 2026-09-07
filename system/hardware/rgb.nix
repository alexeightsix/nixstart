# stage-07: hold the RAM RGB at zero.
#
# Desktop only, and not by convention — the Fury Renegade is the desktop's
# DIMMs. The laptop's 32GB of LPDDR5X is soldered to the board and has no RGB,
# no SPD write path and no /dev/i2c-10.
#
# That last one is the fact worth testing, and the unit now tests it itself:
# ConditionPathExists on the bus means a machine without it skips the unit
# rather than failing a oneshot on every boot. That replaces an assertion
# against `hardware.xps13`, which was a build-time stand-in for the same
# question and got the answer from the host file rather than the hardware.
#
# The option stays, because it gates what cannot detect itself: the i2c group,
# the kernel module and i2c-tools have no business on a machine with no RGB to
# drive, and a skipped unit would still leave all three installed.
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
  config = lib.mkIf config.nixstart.system.hardware.rgb {
    users.groups.i2c = { };
    nixstart.system.user.extraGroups = [ "i2c" ];

    hardware.i2c.enable = true;
    environment.systemPackages = [ pkgs.i2c-tools ];

    systemd.services.rgb = {
      description = "Hold the RAM RGB at zero brightness";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];

      # The bus the DIMMs are on. No bus, no RGB hardware — systemd skips the
      # unit instead of running a oneshot that can only fail.
      unitConfig.ConditionPathExists = "/dev/i2c-10";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe pkgs.fury-renegade-rgb} -b /dev/i2c-10 -2 -4 brightness --value 0";
      };
    };
  };
}
