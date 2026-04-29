{inputs, ...}: {
  flake.modules.nixos.home-manager-integration = {
    home-manager = {
      useGlobalPkgs = true;
      extraSpecialArgs = {inherit inputs;};
    };
  };
}
