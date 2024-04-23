{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tiny-dfr.url = "github:WhatAmISupposedToPutHere/tiny-dfr";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.mbp-m2 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        hosts/mbp-m2/configuration.nix
        inputs.home-manager.nixosModules.default
	      inputs.nixvim.nixosModules.nixvim
      ];
    };
  };
}
