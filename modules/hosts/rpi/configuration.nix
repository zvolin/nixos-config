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

      # end0 (en*) or eth0 (eth*), depending on kernel.
      lanInterface = [
        "en*"
        "eth*"
      ];

      system.stateVersion = "26.11";
    };
}
