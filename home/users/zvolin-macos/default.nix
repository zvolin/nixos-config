{ pkgs, inputs, ... }:
{
  imports = with inputs; [
    home-manager.darwinModules.default

    ../../../nix/homebrew.nix
  ];

  # configure home manager
  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {
      inherit inputs;
    };
    # use system nixpkgs
    useGlobalPkgs = true;
  };

  users.users."zwolin" = {
    shell = pkgs.zsh;
    home = "/Users/zwolin";
  };

  home-manager.users = {
    "zwolin" = import ./home.nix;
  };

  homebrew-user = "zwolin";

  homebrew = {
    casks = [
      "firefox"
      "slack"
    ];
  };
}
