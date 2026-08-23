# stage-07: hold the RAM RGB at zero.
#
# Desktop only, and not by convention — the Fury Renegade is the desktop's
# DIMMs. The laptop's 32GB of LPDDR5X is soldered to the board and has no RGB,
# no SPD write path and no /dev/i2c-10, so turning this on there would add a
# user to an i2c group for nothing and run a oneshot unit that fails on every
# boot. The assertion below makes that a build error rather than a mystery in
# the journal.
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
    assertions = [
      {
        assertion = !config.nixstart.system.hardware.xps13;
        message = ''
          nixstart.system.hardware.rgb is for the desktop's Fury Renegade
          DIMMs. The XPS 13's memory is soldered and has no RGB — turn it off
          on this host.
        '';
      }
    ];

    users.groups.i2c = { };
    nixstart.system.user.extraGroups = [ "i2c" ];

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
