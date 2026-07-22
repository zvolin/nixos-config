{ inputs, ... }:
let
  # Single source of truth for the localhost bind, shared by the home-manager
  # zellij config, the user service, and the NixOS serve front. zellij web
  # binds here; tailscale serve fronts it over the tailnet.
  bindAddress = "127.0.0.1";
  webPort = 8082;
in
{
  flake.modules.nixos.zellij =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home-manager.sharedModules = [ inputs.self.modules.homeManager.zellij ];

      # Front the localhost-only `zellij web` server with `tailscale serve`,
      # which terminates TLS using a MagicDNS certificate and proxies over the
      # tailnet. This must be a RETRYING unit, not a fire-once oneshot: on a
      # fresh boot the node is not yet authenticated (one-time
      # `sudo tailscale up --ssh`) and HTTPS certs may not be enabled, so serve
      # fails. A oneshot that exited 0-on-skip with RemainAfterExit would cache
      # that skip and never configure serve after the user later authenticates.
      # Instead retry every 30 s until BackendState == "Running", then apply
      # serve (which persists in tailscaled state under /persist) and exit 0.
      systemd.services.tailscale-serve-zellij = {
        description = "Front zellij web with tailscale serve (TLS via MagicDNS)";
        after = [
          "tailscaled.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        requires = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          # At most one restart per 30 s, far under systemd's default
          # 5-per-10s start-limit burst, so the retry loop never trips it.
          RestartSec = 30;
          ExecStart = pkgs.writeShellScript "tailscale-serve-zellij" ''
            tailscale=${lib.getExe config.services.tailscale.package}
            jq=${lib.getExe pkgs.jq}
            state=$("$tailscale" status --json 2>/dev/null | "$jq" -r '.BackendState' 2>/dev/null || echo "")
            if [ "$state" != "Running" ]; then
              echo "tailscale BackendState=$state (need Running); retrying"
              exit 1
            fi
            "$tailscale" serve --bg --https=443 http://${bindAddress}:${toString webPort}
          '';
        };
      };
    };

  flake.modules.homeManager.zellij =
    { pkgs, lib, ... }:
    let
      # Attach to (or create) one stable-named session. Long-running Claude /
      # Codex processes live inside it; the zellij server keeps them alive
      # across phone disconnect. `tmux` stays installed for local use.
      remote-session = pkgs.writeShellScriptBin "remote-session" ''
        exec ${lib.getExe pkgs.zellij} attach --create remote
      '';
    in
    {
      programs.zellij = {
        enable = true;
        # Shell auto-start integrations default to false and stay off on
        # purpose: zellij is launched on demand via `remote-session`, not on
        # every terminal. tmux stays the local default.
        settings = {
          # Run a local web server and let terminal-started sessions be shared
          # through it, so the "remote" session is attachable from the phone
          # browser. Bound to localhost; `tailscale serve` fronts it.
          web_server = true;
          web_sharing = "on";
          web_server_ip = bindAddress;
          web_server_port = webPort;
        };
      };

      home.packages = [ remote-session ];

      # Serve the web client on 127.0.0.1 in the foreground under the user
      # session; the NixOS `tailscale serve` front exposes it over the tailnet.
      #
      # This is a `systemd --user` unit, so it only runs while zvolin has an
      # active login session. greetd uses an interactive tuigreet (no
      # autologin) and lingering is off, so after an unattended reboot the web
      # client is down until someone logs in locally. That's a deliberate
      # trade: no user services at boot when logged out. `ssh mbp-m2` +
      # `zellij attach remote` (Tailscale SSH, a system path) is the fallback
      # for reaching a session before then. Enable it across reboots with
      # `users.users.zvolin.linger = true;` if that ever becomes worth it.
      systemd.user.services.zellij-web = {
        Unit.Description = "Zellij web server (localhost, fronted by tailscale serve)";
        Install.WantedBy = [ "default.target" ];
        Service = {
          ExecStart = "${lib.getExe pkgs.zellij} web --start --ip ${bindAddress} --port ${toString webPort}";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
}
