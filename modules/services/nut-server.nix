{ inputs, ... }:
let
  # Shared constants for the server (nas) and client (rpi) aspects so the two
  # can't drift. Mirrors flake.lib.lanConfig. Both labels are arbitrary internal
  # identifiers, not values the UPS hardware dictates.
  nut = {
    upsName = "eaton5e";
    monUser = "upsmon"; # primary account, nas-local upsmon (holds FSD rights)
    monUserRemote = "upsmonsec"; # secondary account for the rpi netclient (no FSD)
  };
in
{
  flake.lib.nut = nut;

  flake.modules.nixos.nut-server =
    { config, ... }:
    {
      # Re-importing sops is idempotent (nas already pulls it via user-sops), so
      # the aspect carries its own secret dependency.
      imports = [ inputs.self.modules.nixos.sops ];

      power.ups = {
        enable = true;
        mode = "netserver";

        ups.${nut.upsName} = {
          driver = "usbhid-ups";
          port = "auto";
          # Coordinated halt fires with ~10 min of runtime left (ride-through,
          # halt-late). PROVISIONAL: override.battery.runtime.low only arms if the
          # driver reports battery.runtime; on this entry-level Eaton 5E the
          # variable can be absent, in which case the install runbook swaps this to
          # override.battery.charge.low after cabling.
          # offdelay/ondelay both measured from kill-power. The ~25 s gap (40 - 15)
          # forces a true power-off so nas cold-boots (its ATX PSU rides through the
          # default 10 s gap and never leaves S5). ondelay must stay > offdelay.
          directives = [
            "override.battery.runtime.low = 600"
            "offdelay = 15"
            "ondelay = 40"
          ];
          description = "Eaton 5E900UD";
        };

        upsd.enable = true;
        # Bind the wildcard rather than the static LAN IP. The upstream upsd unit is
        # Type=forking, orders only on passive network.target with no Restart= and no
        # network-online dependency, so binding the systemd-networkd-assigned static
        # IP can lose a cold-boot race: upsd fails to bind and stays dead until the
        # next reboot — exactly when UPS protection must come up. 0.0.0.0 is a
        # wildcard, not a hard-coded host IP (the "no raw IPs" rule does not apply).
        upsd.listen = [ { address = "0.0.0.0"; } ];

        # Primary account for the nas-local upsmon (holds FSD rights).
        # instcmds is scoped to beeper.disable only: upsmon="primary" grants the
        # monitoring/FSD actions but not instant commands, so `upscmd` is refused
        # without this. We silence the UPS beeper once via upscmd (the setting
        # persists in UPS firmware); granting the single command we ever send
        # keeps least privilege and avoids a dedicated admin account/credential.
        # Scoped to this account only — the rpi netclient uses upsmonsec, which
        # stays instcmd-less.
        users.${nut.monUser} = {
          upsmon = "primary";
          instcmds = [ "beeper.disable" ];
          passwordFile = config.sops.secrets."nut/monitor-password".path;
        };
        # Secondary account for the rpi netclient (no FSD rights). Both read one
        # shared credential: a compromised netclient holds the password and could
        # auth as the primary — one credential value, accepted over strict isolation.
        users.${nut.monUserRemote} = {
          upsmon = "secondary";
          passwordFile = config.sops.secrets."nut/monitor-password".path;
        };

        upsmon.enable = true;
        upsmon.monitor.${nut.upsName} = {
          system = "${nut.upsName}@localhost";
          user = nut.monUser;
          passwordFile = config.sops.secrets."nut/monitor-password".path;
          powerValue = 1;
          type = "primary";
        };

        # Opens :3493 for the netclient; on a single-NIC host this exposes only
        # the LAN interface.
        openFirewall = true;
      };

      # One shared monitor credential, the same value on both ends of the monitor
      # relationship. host_nas + host_rpi already decrypt shared.yaml today
      # (hashedPasswordFile), so no new .sops.yaml recipients. The module reads
      # passwordFile at runtime via systemd LoadCredential, so the cleartext never
      # enters the Nix store.
      sops.secrets."nut/monitor-password" = {
        sopsFile = "${inputs.secrets}/shared.yaml";
        # The secret path is value-independent, so rotating the password changes
        # no unit definition and nixos-rebuild won't restart upsd/upsmon on its
        # own. Without restartUnits, they'd keep serving the stale /run/nut/*.users
        # until a manual restart.
        restartUnits = [
          "upsd.service"
          "upsmon.service"
        ];
      };
    };
}
