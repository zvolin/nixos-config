{ inputs, ... }:
{
  flake.modules.nixos.mbp-m2 =
    { config, pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-desktop
        ./_host/hardware-configuration.nix
        asahi
        boot-grub
        impermanence
        networking
        overlay-freecad
        overlay-nettle
        overlay-pdal
        overlay-tiny-dfr
        overlay-vtk
        stylix
        nixvim
        docker
        xremap
        searxng
        tiny-dfr
        zvolin
      ];

      networking.hostName = "mbp-m2";
      hardware.asahi.peripheralFirmwareDirectory =
        pkgs.runCommand "asahi-firmware-cpio"
          {
            nativeBuildInputs = [ config.hardware.asahi.pkgs.asahi-fwextract ];
          }
          ''
            mkdir -p $out
            asahi-fwextract ${./_host/firmware} $out
          '';
      system.stateVersion = "24.05";

      environment.variables.WLR_DRM_DEVICES = "/dev/dri/card0";

      services.tiny-dfr.enable = true;
    };
}
