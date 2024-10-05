{ ... }:

{
  imports = [
    # internationalization settings
    ./i18n.nix
    # vim
    ./nixvim
    # sddm
    ./sddm.nix
    # stylix
    ./stylix.nix
    # touchbar
    ./tiny-dfr
  ];

  options = { };

  config = {
    # before hyprlock#434 is fixed
    security.pam.services.swaylock = { };
  };
}
