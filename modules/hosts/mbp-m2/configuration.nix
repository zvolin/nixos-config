{ inputs, ... }:

{
  flake.modules.nixos.mbp-m2 = {
    imports = with inputs.self.modules.nixos; [
      system-desktop
      ./_host/hardware-configuration.nix
      asahi
      boot-grub
      impermanence
      networking
      overlay-nettle
      overlay-tiny-dfr
      stylix
      nixvim
      docker
      xremap
      searxng
      tiny-dfr
      zvolin
    ];

    networking.hostName = "mbp-m2";
    hardware.asahi.peripheralFirmwareDirectory = ./_host/firmware;
    system.stateVersion = "24.05";

    environment.variables.WLR_DRM_DEVICES = "/dev/dri/card0";

    services.tiny-dfr.enable = true;
  };
}
