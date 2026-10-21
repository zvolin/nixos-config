{ inputs, lib, ... }:
{
  # One role: a headless, wired-LAN server reached by LAN SSH. Folds the three
  # blocks nas and rpi each repeated — firewall door, static-IP 10-lan, and the
  # from-disk SSH commit-signing identity — into one import. Composes with
  # networking-wired (which already sets useDHCP = false).
  flake.modules.nixos.headless-host =
    { config, ... }:
    let
      lan = inputs.self.lib.lanConfig;
    in
    {
      # openssh (via system-cli) keeps TCP 22 closed; a headless box reached only
      # over LAN needs this explicit door. Authorized client keys come from the
      # user-headless mesh, not a per-host block.
      networking.firewall.allowedTCPPorts = [ 22 ];

      # Host-static IP from the private LAN map (no raw IPs here, no drift).
      # matchConfig.Name defaults to nas's single-NIC "en*"; rpi overrides it.
      # With useDHCP = false + firewall on, a missed match leaves the box dark,
      # so a widened default is never applied to the un-recoverable x86 host.
      systemd.network.networks."10-lan" = {
        matchConfig.Name = lib.mkDefault "en*";
        address = [ "${lan.hosts.${config.networking.hostName}}/${toString lan.prefixLength}" ];
        networkConfig = {
          Gateway = lan.gateway;
          DNS = lan.dns;
        };
      };

      # Commit-signing from disk (a file path, not a key:: literal) so the
      # headless box signs without an ssh-agent. Username is literal by design.
      home-manager.users.zwolin.programs.git.signing = {
        format = "ssh";
        key = "/home/zwolin/.ssh/id_ed25519";
      };
    };
}
