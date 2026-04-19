{ inputs, ... }:

{
  flake.modules.nixos.asahi = {
    imports = [ inputs.nixos-apple-silicon.nixosModules.default ];
    hardware.graphics.enable = true;
  };
}
