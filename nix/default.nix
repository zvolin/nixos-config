{ lib, pkgs, config, inputs, ... }:

{
  imports = [
    # internationalization settings
    ./i18n.nix
    # user settings
    ../users
    # touchbar
    ./tiny-dfr
    # sddm
    ./sddm
  ];

  options = {};

  config = {
    # load configuration for given users
    user-config.users = [ "zwolin" ];
  };
}
