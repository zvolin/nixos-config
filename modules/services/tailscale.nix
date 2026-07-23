{ ... }:
{
  flake.modules.nixos.tailscale =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      services.tailscale.enable = true;

      # tailscaled keeps node identity and `tailscale serve` config under
      # /var/lib/tailscale, which the root-wipe (impermanence) would erase every
      # boot. Bind-mount it from /persist so the node stays authenticated.
      #
      # It has to be a bind mount, not a tmpfiles symlink (the greetd pattern):
      # the upstream unit sets StateDirectory=tailscale, and systemd refuses to
      # set up a StateDirectory whose path is a symlink -- it fails with ELOOP
      # ("Too many levels of symbolic links") before tailscaled starts. greetd's
      # cache dir has no StateDirectory, so a symlink is fine there but not here.
      # A bind mount makes /var/lib/tailscale a real directory backed by
      # /persist, which StateDirectory accepts. systemd creates the mountpoint on
      # boot, and the persisted source below survives the wipe.
      systemd.tmpfiles.settings."10-tailscale"."/persist/var/lib/tailscale".d = {
        user = "root";
        group = "root";
        mode = "0700";
      };

      fileSystems."/var/lib/tailscale" = {
        device = "/persist/var/lib/tailscale";
        fsType = "none";
        options = [ "bind" ];
      };

      # Enable Tailscale SSH declaratively. tailscaled intercepts tailnet port 22
      # at the daemon level once `--ssh` is set, so the phone reaches a full
      # terminal with `ssh mbp-m2` over the tailnet, then `zj` (fzf session
      # picker) or the `nvim` alias to enter a project's zellij session -- no
      # public port, no password, no key on the phone (tailnet identity is the
      # auth).
      #
      # Phone-side app ladder (the final pick is dogfood ticket 35's call):
      # TabSSH -> Termux + extra-keys -> Unexpected Keyboard IME.
      #
      # This must be a RETRYING unit, not a fire-once oneshot: on a fresh boot
      # the node is not yet authenticated (auth stays the one-time manual
      # `sudo tailscale up`), so `tailscale set` fails until
      # BackendState == "Running". Retry every 30 s until Running, then apply
      # `--ssh` (idempotent; the preference persists in the bind-mounted
      # /var/lib/tailscale state) and exit 0.
      #
      # `--ssh` takes effect only if the tailnet ACL has an `ssh` stanza with
      # action "accept" (admin console, not declarable here). A "check" action
      # forces ~12 h browser re-auth and breaks headless phone use.
      #
      # Fallback if Tailscale SSH ever proves awkward (e.g. with Mosh): because
      # tailscaled intercepts tailnet :22 *before* sshd, merely opening TCP 22
      # does not reach sshd. Disabling this unit is NOT enough -- it only stops
      # the unit re-asserting on the next boot; the `--ssh` preference persists
      # in /var/lib/tailscale, so tailscaled keeps intercepting :22 until it is
      # actively cleared. To activate the fallback:
      #   1. `tailscale set --ssh=false` -- stop tailscaled intercepting :22 now.
      #   2. Disable this unit so it does not re-assert `--ssh` on the next boot.
      #   3. Re-open 22 on the tailnet only (openFirewall=false closed it on
      #      every interface, tailscale0 included):
      #        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];
      #   4. Add an authorized key -- with Tailscale SSH there is no key on the
      #      phone today, so the hardened sshd would reject the connection.
      systemd.services.tailscale-ssh = {
        description = "Enable Tailscale SSH (tailscale set --ssh)";
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
          ExecStart = pkgs.writeShellScript "tailscale-ssh" ''
            tailscale=${lib.getExe config.services.tailscale.package}
            jq=${lib.getExe pkgs.jq}
            state=$("$tailscale" status --json 2>/dev/null | "$jq" -r '.BackendState' 2>/dev/null || echo "")
            if [ "$state" != "Running" ]; then
              echo "tailscale BackendState=$state (need Running); retrying"
              exit 1
            fi
            "$tailscale" set --ssh
          '';
        };
      };
    };
}
