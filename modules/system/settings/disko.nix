{ inputs, ... }:
{
  # Wraps disko's NixOS module so a host gets declarative disk layout — and the
  # `fileSystems` disko generates from it — by importing `disko` alone. Named
  # variant aspects (nas-disko, mbp-disko) import this and declare `disko.devices`.
  # Mirrors how `sops.nix` wraps sops-nix.
  flake.modules.nixos.disko = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
