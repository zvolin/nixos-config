{ ... }:
{
  flake.modules.nixos.igpu-render =
    { pkgs, ... }:
    {
      # iGPU (UHD 770) with the Intel VAAPI driver.
      hardware.graphics = {
        enable = true;
        extraPackages = [ pkgs.intel-media-driver ];
      };
    };
}
