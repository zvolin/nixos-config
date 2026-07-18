{ inputs, ... }:
{
  flake.modules.nixos.asahi = {
    imports = [ inputs.nixos-apple-silicon.nixosModules.default ];
    hardware.asahi.enable = true;
    hardware.graphics.enable = true;
  };
}
