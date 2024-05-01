{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "aarch64-linux";
    in {
      nixosConfigurations.mbp-m2 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = with inputs; [
          hosts/mbp-m2/configuration.nix

          # Include the necessary packages and configuration for Apple Silicon support
          nixos-apple-silicon.nixosModules.default
          # { nixpkgs.overlays = [ nixos-apple-silicon.overlays.default ]; } # is this needed? it requires impure

          home-manager.nixosModules.default
	        nixvim.nixosModules.nixvim

          # ({ pkgs, inputs, ... }: {
          #   environment.systemPackages = [ inputs.tiny-dfr.${pkgs.system}.packages.default ];
          # })
        ];
      };
    };
}
