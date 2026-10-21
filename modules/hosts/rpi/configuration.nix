{ inputs, ... }:
{
  flake.modules.nixos.rpi =
    { ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-cli
        rpi-sdimage
        ./_host/hardware.nix
        networking-wired
        lan-hosts
        headless-host
        user-headless
        user-sops
        nut-client
      ];

      networking.hostName = "rpi";

      # end0 + the eth0 fallback; wlan0 matches neither. The runbook confirms
      # the NIC name on first console boot (a missed match leaves the box dark).
      systemd.network.networks."10-lan".matchConfig.Name = "en* eth*";

      system.stateVersion = "26.11";
    };
}
