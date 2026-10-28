{ inputs, lib, ... }:
{
  # Headless wired-LAN server: SSH door, static IP, commit-signing key.
  flake.modules.nixos.headless-host =
    { config, ... }:
    let
      lan = inputs.self.lib.lanConfig;
      lanIfaces = config.lanInterface;
    in
    {
      options.lanInterface = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "en*"
          "eth*"
        ];
        description = "LAN interface name-globs to scope the SSH door and 10-lan match to; [ ] = global SSH.";
      };

      config = {
        networking.firewall =
          if lanIfaces == [ ] then
            { allowedTCPPorts = [ 22 ]; }
          else
            {
              interfaces = lib.genAttrs lanIfaces (_: {
                allowedTCPPorts = [ 22 ];
              });
            };

        systemd.network.networks."10-lan" = {
          matchConfig.Name =
            if lanIfaces == [ ] then lib.mkDefault "en*" else lib.concatStringsSep " " lanIfaces;
          address = [ "${lan.hosts.${config.networking.hostName}}/${toString lan.prefixLength}" ];
          networkConfig = {
            Gateway = lan.gateway;
            DNS = lan.dns;
          };
        };

        home-manager.users.zwolin.programs.git.signing = {
          format = "ssh";
          key = "/home/zwolin/.ssh/id_ed25519";
        };
      };
    };
}
