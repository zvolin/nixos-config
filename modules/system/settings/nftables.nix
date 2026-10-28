{ ... }:
{
  # nftables firewall backend, fleet-wide.
  flake.modules.nixos.nftables.networking.nftables.enable = true;
}
