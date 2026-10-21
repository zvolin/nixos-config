{ inputs, ... }:
{
  flake.nixosConfigurations.nas = inputs.self.lib.mkNixos "x86_64-linux" "nas";
}
