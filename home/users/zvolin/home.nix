{ inputs, ... }:

{
  imports = with inputs; [
    nix-colors.homeManagerModules.default
    nixvim.homeManagerModules.nixvim

    ../../chromium.nix
    ../../firefox.nix
    ../../fzf.nix
    ../../git.nix
    ../../hyprland.nix
    ../../hyprlock.nix
    ../../hypridle.nix
    ../../keychain.nix
    ../../kitty.nix
    ../../waybar.nix
    ../../wofi.nix
    ../../zsh.nix
  ];

  home.username = "zwolin";
  home.homeDirectory = "/home/zwolin";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # export manual as json
  manual.json.enable = true;
  # enable management of xdg directories
  xdg.enable = true;

  # enable qt and gtk configs
  qt.enable = true;
  gtk.enable = true;
}
