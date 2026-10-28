{ inputs, ... }:
{
  flake.modules.nixos.ntfy =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      ntfy = import ./_ntfy-common.nix;
      authFile = config.services.ntfy-sh.settings.auth-file;
      # Seed runs ExecStartPost (not Pre) because ntfy's `user`/`access` refuse to
      # run until the server creates the sqlite auth-file; runs as the service's own
      # DynamicUser so the db stays dynamic-uid-owned; password arrives via
      # LoadCredential (a DynamicUser can't own a sops secret); `change-pass` every
      # start lands a sops rotation.
      seed = pkgs.writeShellApplication {
        name = "ntfy-seed-auth";
        runtimeInputs = [
          config.services.ntfy-sh.package
          pkgs.coreutils
        ];
        text = ''
          export NTFY_CONFIG_FILE=/etc/ntfy/server.yml
          password=$(cat "$CREDENTIALS_DIRECTORY/publisher-password")

          # Wait for the server to create the auth-file (it does so early in
          # startup; ExecStartPost can fire first). Bounded so a server that never
          # starts fails the unit instead of hanging.
          for _ in $(seq 1 50); do
            [ -s "${authFile}" ] && break
            sleep 0.1
          done
          if [ ! -s "${authFile}" ]; then
            echo "ntfy-seed-auth: ${authFile} not created by the server" >&2
            exit 1
          fi

          # Create users if absent (idempotent via --ignore-exists). The reader password is unused (phone uses a minted token), so it needs no change-pass.
          NTFY_PASSWORD="$password" ntfy user add --ignore-exists --role=user "${ntfy.publisherUser}"
          NTFY_PASSWORD="$password" ntfy user add --ignore-exists --role=user "${ntfy.readerUser}"

          # Rotation-safe: force the publisher password to the current secret on
          # every start, so a restartUnits reseed after a sops rotation lands.
          NTFY_PASSWORD="$password" ntfy user change-pass "${ntfy.publisherUser}"

          # ACL grants are a set, so they converge on re-run.
          ntfy access "${ntfy.publisherUser}" "${ntfy.healthTopic}" rw
          ntfy access "${ntfy.publisherUser}" "${ntfy.agentTopic}" rw
          ntfy access "${ntfy.readerUser}" "${ntfy.healthTopic}" ro
          ntfy access "${ntfy.readerUser}" "${ntfy.agentTopic}" ro
        '';
      };
    in
    {
      imports = [ inputs.self.modules.nixos.ntfy-publisher-secret ];

      services.ntfy-sh = {
        enable = true;
        settings = {
          # Deny-by-default: every publish and subscribe needs a seeded user with an ACL grant.
          auth-default-access = "deny-all";
          # Bind all interfaces so LAN publishers and 127.0.0.1 producers both reach it; reachability is fenced by the per-interface firewall.
          listen-http = ":${toString ntfy.port}";
          base-url = "http://${config.networking.hostName}:${toString ntfy.port}";
        };
      };

      systemd.services.ntfy-sh.serviceConfig = {
        LoadCredential = "publisher-password:${config.sops.secrets."ntfy/publisher-password".path}";
        ExecStartPost = lib.getExe seed;
      };

      # Reseed on a publisher-password rotation. The secret path is
      # value-independent, so without this nothing would restart the server and
      # the seeded password would stay stale.
      sops.secrets."ntfy/publisher-password".restartUnits = [ "ntfy-sh.service" ];

      # Admit ntfy port on the LAN interface(s) via the lanInterface seam; `en*` is an nftables wildcard.
      networking.firewall.interfaces = lib.genAttrs config.lanInterface (_: {
        allowedTCPPorts = [ ntfy.port ];
      });
    };
}
