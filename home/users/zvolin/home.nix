{ inputs, pkgs, ... }:

{
  imports = with inputs; [
    nix-colors.homeManagerModules.default
    nixvim.homeModules.nixvim

    ../../audio.nix
    ../../bash.nix
    ../../brightness.nix
    ../../chromium.nix
    ../../claude
    ../../connman.nix
    # ../../cosmic.nix
    ../../firefox.nix
    ../../fzf.nix
    ../../git.nix
    ../../hyprland.nix
    ../../hypridle.nix
    ../../hyprlock.nix
    ../../keychain.nix
    ../../kitty.nix
    ../../latex.nix
    ../../mako.nix
    ../../terminal.nix
    ../../waybar.nix
    ../../wofi.nix
    ../../zathura.nix
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
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  home.packages = with pkgs; [
    freecad
    gh
    codex
  ];

  home.sessionVariables = {
    XCURSOR_SIZE = "14";
  };

  # export manual as json
  manual.json.enable = true;
  # enable management of xdg directories
  xdg.enable = true;

  # enable qt and gtk configs
  qt.enable = true;
  gtk.enable = true;
  gtk.gtk4.theme = null;
}
