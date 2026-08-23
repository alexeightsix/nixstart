# Dell XPS 13 9350 (Lunar Lake).
#
#   Core Ultra 7 258V (Series 2), 8 cores      Intel Arc 140V graphics
#   32GB LPDDR5X-8533, soldered                Killer Wi-Fi 7 BE201 + BT 5.4
#   Platinum backlit keyboard, fingerprint     60W USB-C charger
#
# Shipped with Ubuntu 24.04, so it is a Dell-certified Linux machine and the
# awkward parts are firmware and kernel version rather than missing drivers.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.system.hardware;
in
{
  options.kickstart.system.hardware.xps13 = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Dell XPS 13 9350 — Lunar Lake platform support.";
  };

  config = lib.mkIf cfg.xps13 {
    # Lunar Lake is new enough that the LTS kernel is the wrong default here:
    # Xe2 graphics, the BE201 wifi and the SOF audio topology all landed
    # across 6.11–6.13. The distro kernel on the machine today is 6.x from
    # Ubuntu 24.04's HWE stack for the same reason.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    hardware.cpu.intel.updateMicrocode = true;
    hardware.enableRedistributableFirmware = true;
    boot.kernelModules = [ "kvm-intel" ];

    # Arc 140V is driven by `xe`, not `i915`. Both are built in; the newer
    # kernels pick xe for Lunar Lake on their own, and this makes it explicit
    # rather than depending on that default holding.
    boot.kernelParams = [
      "i915.force_probe=!7d55"
      "xe.force_probe=7d55"
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # iHD — VA-API for Xe2
        vpl-gpu-rt # QSV encode/decode
        intel-compute-runtime
      ];
    };

    environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

    # Lunar Lake has no S3; suspend is s2idle (modern standby). Saying so
    # avoids the kernel picking a state the firmware does not implement.
    systemd.sleep.settings.Sleep.SuspendState = "freeze";

    # Audio needs the SOF firmware on this platform; without it the speakers
    # and the internal mic simply do not appear.
    hardware.firmware = [ pkgs.sof-firmware ];

    # The fingerprint reader in the "Platinum Backlit ... with Fingerprint
    # Reader" option. fprintd drives it for login and sudo; if enrolment
    # fails, this is the thing to turn off first — nothing else depends on it.
    services.fprintd.enable = lib.mkDefault true;

    # Battery. power-profiles-daemon rather than TLP: it is what the
    # Dell-certified Ubuntu image uses, it cooperates with upower, and the two
    # conflict if both are on.
    services.power-profiles-daemon.enable = true;
    services.upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 5;
      criticalPowerAction = "Hibernate";
    };

    services.thermald.enable = true;

    # Lid, power button, and the keyboard backlight.
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandlePowerKey = "suspend";
    };

    environment.systemPackages = with pkgs; [
      brightnessctl
      powertop
      intel-gpu-tools
      acpi
    ];

    networking.networkmanager.wifi.backend = "iwd";
  };
}
