{ inputs, ... }:
{
  flake.nixosConfigurations.rpi = inputs.self.lib.mkNixos "aarch64-linux" "rpi";
}
