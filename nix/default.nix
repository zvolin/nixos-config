{ ... }:

{
  imports = [
    # internationalization settings
    ./i18n.nix
    # vim
    ./nixvim
    # sddm
    ./sddm
    # stylix
    ./stylix.nix
    # touchbar
    ./tiny-dfr
    # user settings
    ../users
  ];

  options = { };

  config = {
    # load configuration for given users
    user-config.users = [ "zwolin" ];
  };
}
