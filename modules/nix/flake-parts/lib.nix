{ inputs, ... }:

{
  flake.lib = {
    # HM wired unconditionally — every host in this config uses it
    mkNixos =
      system: name:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          inputs.self.modules.nixos.${name}
          inputs.home-manager.nixosModules.default
        ];
      };

    # Stubs — implement when adding Darwin or standalone HM hosts
    mkDarwin = _system: _name: throw "mkDarwin: not yet implemented";
    mkHomeManager = _system: _name: throw "mkHomeManager: not yet implemented";
  };
}
