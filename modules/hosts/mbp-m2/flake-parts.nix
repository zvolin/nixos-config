{inputs, ...}: {
  flake.nixosConfigurations.mbp-m2 =
    inputs.self.lib.mkNixos "aarch64-linux" "mbp-m2";
}
