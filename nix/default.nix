{ ... }:

{
  imports = [
    # internationalization settings
    ./i18n.nix
    # vim
    ./nixvim
    # stylix
    ./stylix.nix
    # touchbar
    ./tiny-dfr.nix
  ];

  options = { };

  config = {
    # before hyprlock#434 is fixed
    security.pam.services.swaylock = { };
  };
}
