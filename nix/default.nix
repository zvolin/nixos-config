{ lib, pkgs, config, inputs, ... }:

{
  imports = [
    # internationalization settings
    ./i18n.nix
    # user settings
    ../users/default.nix
    # touchbar
    ./tiny-dfr/default.nix
  ];

  options = {};

  config = {
    # load configuration for given users
    user-config.users = [ "zwolin" ];
  };
}
