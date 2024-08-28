{ pkgs, inputs, ... }:

{
  imports = with inputs; [
    nix-colors.homeManagerModules.default
    nixvim.homeManagerModules.nixvim

    ../../home/hyprland.nix
    ../../home/hyprlock.nix
    ../../home/hypridle.nix
    ../../home/keychain.nix
    ../../home/waybar.nix
    ../../home/wofi.nix
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

    wl-color-picker

    # (pkgs.callPackage ../../home/bibata-cursors-hypr.nix { inherit args; })
    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # "${config.xdg.dataHome}/icons/${cursor_theme}-Hypr".source = "${bibata-cursors-hypr}/share/icons/${cursor_theme}-Hypr";

    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

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

  programs.fzf =
    let
      fd = "fd --type f";
    in
    {
      enable = true;

      defaultCommand = fd;
      changeDirWidgetCommand = fd;
      fileWidgetCommand = fd;
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

    antidote = {
      enable = true;
      plugins = [ ];
    };
  };

  # prompt
  programs.starship.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
