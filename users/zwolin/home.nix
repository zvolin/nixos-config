{ config, pkgs, inputs, ... }@args:


let
  # bibata-cursors-hypr = pkgs.callPackage ../../home-manager-modules/bibata-cursors-hypr.nix { };
in {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.nixvim.homeManagerModules.nixvim

    ../../home/hyprland.nix
    ../../home/nixvim.nix
    ../../home/waybar.nix
    ../../home/wofi.nix
    # ../../home/lunarvim.nix
  ];

  home.username = "zwolin";
  home.homeDirectory = "/home/zwolin";

  colorScheme = inputs.nix-colors.colorSchemes.ayu-mirage;

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

    (pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; })

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

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 18;
  };

  qt.enable = true;

  gtk = let
    inherit (inputs.nix-colors.lib.contrib { inherit pkgs; }) gtkThemeFromScheme;
  in {
    enable = true;
    theme = {
      package = gtkThemeFromScheme { scheme = config.colorScheme; };
      name = config.colorScheme.slug;
    };
  
    iconTheme = {
      package = pkgs.gnome.adwaita-icon-theme;
      name = "Adwaita";
    };
  
    font = {
      name = "Sans";
      size = 11;
    };
  };

  # setup terminal emulator
  programs.kitty = {
    enable = true;
    settings = {
      scrollback_lines = 20000;
      enable_audio_bell = false;
      # don't ask for confirmation to close window
      confirm_os_window_close = 0;

      background = "#${config.colorScheme.palette.base00}";
      foreground = "#${config.colorScheme.palette.base05}";
      selection_background = "#${config.colorScheme.palette.base05}";
      selection_foreground = "#${config.colorScheme.palette.base00}";
      url_color = "#${config.colorScheme.palette.base04}";
      cursor = "#${config.colorScheme.palette.base05}";
      active_border_color = "#${config.colorScheme.palette.base03}";
      inactive_border_color = "#${config.colorScheme.palette.base01}";
      active_tab_background = "#${config.colorScheme.palette.base00}";
      active_tab_foreground = "#${config.colorScheme.palette.base05}";
      inactive_tab_background = "#${config.colorScheme.palette.base01}";
      inactive_tab_foreground = "#${config.colorScheme.palette.base04}";
      tab_bar_background = "#${config.colorScheme.palette.base01}";
      
      # = normal
      color0 = "#${config.colorScheme.palette.base00}";
      color1 = "#${config.colorScheme.palette.base08}";
      color2 = "#${config.colorScheme.palette.base0B}";
      color3 = "#${config.colorScheme.palette.base0A}";
      color4 = "#${config.colorScheme.palette.base0D}";
      color5 = "#${config.colorScheme.palette.base0E}";
      color6 = "#${config.colorScheme.palette.base0C}";
      color7 = "#${config.colorScheme.palette.base05}";
      
      # = bright
      color8 = "#${config.colorScheme.palette.base03}";
      color9 = "#${config.colorScheme.palette.base09}";
      color10 = "#${config.colorScheme.palette.base01}";
      color11 = "#${config.colorScheme.palette.base02}";
      color12 = "#${config.colorScheme.palette.base04}";
      color13 = "#${config.colorScheme.palette.base06}";
      color14 = "#${config.colorScheme.palette.base0F}";
      color15 = "#${config.colorScheme.palette.base07}";
    };

    font = {
      name = "FiraCode Nerd Font Mono";
      package = pkgs.nerdfonts;
      size = 10.0;
    };
  };

  programs.fzf = let
    fd = "fd --type f";
  in {
    enable = true;

    defaultCommand = fd;
    colors = {
      bg = "#${config.colorScheme.palette.base00}";
      "bg+" = "#${config.colorScheme.palette.base01}";
      fg = "#${config.colorScheme.palette.base04}";
      "fg+" = "#${config.colorScheme.palette.base06}";
      hl = "#${config.colorScheme.palette.base0D}";
      "hl+" = "#${config.colorScheme.palette.base0D}";
      info = "#${config.colorScheme.palette.base0A}";
      marker = "#${config.colorScheme.palette.base0C}";
      header = "#${config.colorScheme.palette.base0D}";
      prompt = "#${config.colorScheme.palette.base0A}";
      spinner = "#${config.colorScheme.palette.base0C}";
      pointer = "#${config.colorScheme.palette.base0C}";
    };
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
      plugins = [];
    };
  };

  # prompt
  programs.starship.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
