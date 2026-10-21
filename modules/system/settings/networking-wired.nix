{ ... }:
{
  flake.modules.nixos.networking-wired = {
    systemd.network.enable = true;
    networking.useDHCP = false;
    networking.firewall.enable = true;
    services.resolved.enable = true;
    # A down NIC must not hang a headless boot.
    systemd.network.wait-online.anyInterface = true;
  };
}
