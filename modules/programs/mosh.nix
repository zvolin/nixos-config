{ ... }:
{
  flake.modules.nixos.mosh =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.mosh ];

      # Admit Mosh's UDP range only from the tailnet interface, never the LAN
      # (same tailnet-only pattern ntfy.nix uses for TCP). Mosh is present so
      # dogfood ticket 35 can evaluate it against plain SSH; plain SSH over
      # the tailnet stays the transport baseline until then.
      networking.firewall.interfaces."tailscale0".allowedUDPPortRanges = [
        {
          from = 60000;
          to = 61000;
        }
      ];
    };
}
