{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.user-config;
in {
  # import all per-user configurations
  imports = [
    ./zwolin/user.nix
  ];

  options.user-config = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        list of usernames for which to load configuration
      '';
      default = [ ];
    };
  };

  config = {
    # enable configurations for selected users
    zwolin.enable = lib.mkIf (lib.lists.any (u: u == "zwolin") cfg.users) true;

    # don't allow tweaking users outside of config
    users.mutableUsers = false;

    # configure home manager
    home-manager = {
      # also pass inputs to home-manager modules
      extraSpecialArgs = { inherit inputs; };
      # use system nixpkgs
      useGlobalPkgs = true;
    };
  };
}
