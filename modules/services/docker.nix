{ ... }:
{
  flake.modules.nixos.docker = {
    virtualisation = {
      containers.enable = true;
      docker.enable = true;
    };

    networking.nftables.enable = false;
    networking.firewall = {
      extraCommands = "
        iptables -I nixos-fw 1 -i br+ -j ACCEPT
      ";
      extraStopCommands = "
        iptables -D nixos-fw -i br+ -j ACCEPT
      ";
    };
  };
}
