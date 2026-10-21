{ inputs, ... }:
{
  flake.modules.nixos.nut-client =
    { config, ... }:
    let
      # Shared NUT identity, registered in nut-server.nix. flake.lib is
      # flake-global (merged via lib-option.nix), so rpi reads it without importing
      # the server aspect — the same pattern nas uses for inputs.self.lib.lanConfig.
      nut = inputs.self.lib.nut;
    in
    {
      # Self-contained; re-importing sops is idempotent (rpi already pulls it via
      # user-sops).
      imports = [ inputs.self.modules.nixos.sops ];

      power.ups = {
        enable = true;
        mode = "netclient";

        upsmon.enable = true;
        upsmon.monitor.${nut.upsName} = {
          # "nas" resolves via networking.hosts (lan-hosts, already imported by
          # rpi) — no raw IP. Secondary role halts first. The primary's HOSTSYNC
          # gives it a bounded wait (default 15 s) to drop off before cutting UPS
          # power, so the halt ordering is best-effort, not a hard guarantee.
          system = "${nut.upsName}@nas";
          # Authenticate as the secondary account (no FSD rights), not the primary.
          # This confines rpi's own well-behaved upsmon; a compromised host still
          # holds the shared password and could auth as the primary.
          user = nut.monUserRemote;
          passwordFile = config.sops.secrets."nut/monitor-password".path;
          powerValue = 1;
          type = "secondary";
        };
      };

      # Same shared credential as the server side; host_rpi already decrypts
      # shared.yaml. Runtime LoadCredential keeps the cleartext out of the store.
      sops.secrets."nut/monitor-password" = {
        sopsFile = "${inputs.secrets}/shared.yaml";
        # The secret path is value-independent, so rotating the password changes
        # no unit definition. Without restartUnits, upsmon keeps the stale
        # /run/nut/upsmon.conf until a manual restart.
        restartUnits = [ "upsmon.service" ];
      };
    };
}
