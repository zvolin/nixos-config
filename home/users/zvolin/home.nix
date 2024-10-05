{ pkgs, inputs, ... }:

{
  imports = with inputs; [
    nix-colors.homeManagerModules.default
    nixvim.homeManagerModules.nixvim

    ../../hyprland.nix
    ../../hyprlock.nix
    ../../hypridle.nix
    ../../keychain.nix
    ../../waybar.nix
    ../../wofi.nix
  ];

  # export manual as json
  manual.json.enable = true;

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

  home.packages = with pkgs; [
    firefox
    ungoogled-chromium
    wl-color-picker
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };

  # enable management of xdg directories
  xdg.enable = true;

  # todo, requires secrets?
  programs.git = {
    enable = true;
    signing.key = "9DD9C8FD06750734";
    signing.signByDefault = true;
  };

  qt.enable = true;

  gtk.enable = true;

  # setup terminal emulator
  programs.kitty = {
    enable = true;
    settings = {
      scrollback_lines = 20000;
      enable_audio_bell = false;
      # don't ask for confirmation to close window
      confirm_os_window_close = 0;
      window_padding_width = 1;
    };
  };

  programs.fzf = {
    enable = true;

    defaultCommand = "fd --type f";
    defaultOptions = [
      "--layout=reverse"
      "--inline-info"
    ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # let terminal track current dir
    enableVteIntegration = true;

    history = {
      expireDuplicatesFirst = true;
      save = 50000;
      size = 20000;
    };

    oh-my-zsh.enable = true;
  };

  # prompt
  programs.starship.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
