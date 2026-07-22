{ ... }:
{
  flake.modules.nixos.ntfy =
    { config, pkgs, ... }:
    let
      notify = import ./_notify-push.nix { inherit pkgs; };
    in
    {
      services.ntfy-sh = {
        enable = true;
        settings = {
          # Bind all interfaces; reachability is fenced to the tailnet by the
          # firewall rule below (the tailnet IP is dynamic, so a per-interface
          # firewall allow is the declarative equivalent of a tailnet-only bind).
          listen-http = ":${toString notify.port}";
          # No auth, no upstream-base-url: the tailnet is the boundary and the
          # Android app connects directly to this host (no ntfy.sh relay). The
          # base-url only feeds generated links; MagicDNS resolves the short
          # host name inside the tailnet.
          base-url = "http://${config.networking.hostName}:${toString notify.port}";
        };
      };

      # Admit the ntfy port only from the tailnet interface, never the LAN.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ notify.port ];
    };
}
