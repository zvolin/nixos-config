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

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # tiny-dfr.url = "github:WhatAmISupposedToPutHere/tiny-dfr";
    # tiny-dfr = {
    #   url = "path:/persist/etc/nixos/flakes/tiny-dfr";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "aarch64-linux";
    in {
      nixosConfigurations.mbp-m2 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          hosts/mbp-m2/configuration.nix
          inputs.home-manager.nixosModules.default
	        inputs.nixvim.nixosModules.nixvim
          # ({ pkgs, inputs, ... }: {
          #   environment.systemPackages = [ inputs.tiny-dfr.${pkgs.system}.packages.default ];
          # })
        ];
      };
    };
}
