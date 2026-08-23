# The guest that runs an agent, as an Incus instance.
#
# One definition, built two ways (see flake.nix):
#
#   agent-container   an Incus container. Shares the host kernel, boots in
#                     under a second, costs almost nothing to throw away.
#   agent-vm          an Incus virtual machine. Its own kernel, so code the
#                     agent runs cannot reach the host through a shared one.
#
# Prefer the VM when the agent is running code you have not read. Prefer the
# container when you are the one driving it and want it instantly.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../../profiles/agent-vm.nix ];

  networking.hostName = lib.mkDefault "agent";

  nixstart.devEnv = {
    languages = [
      "go"
      "node"
    ];
    agents = true;
  };

  # Incus reaches into the instance through this, which is what makes
  # `incus exec` and `incus file push` work without ssh.
  virtualisation.incus.agent.enable = true;

  # Incus hands out addresses on its own bridge.
  networking.useDHCP = lib.mkDefault true;
  networking.firewall.enable = lib.mkDefault true;

  # Nothing in a disposable guest should be waiting on the network to finish
  # booting, and a unit that hangs on shutdown is what turns `incus stop` into
  # a two-minute wait.
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkDefault false;

  # Bound how long shutdown can take. The default is 90 seconds per job, which
  # on a guest you are throwing away is 90 seconds of nothing useful.
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
    DefaultTimeoutStartSec = "30s";
  };

  # No initrd line here: it means nothing in a container, and the VM gets its
  # own from incus-virtual-machine.nix.

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  system.stateVersion = "25.05";
}
