{ config, pkgs, inputs, ... }:


let
  # bibata-cursors-hypr = pkgs.callPackage ../../home-manager-modules/bibata-cursors-hypr.nix { };
in {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim

    ../../home/waybar.nix
    ../../home/nixvim.nix
    # ../../home/lunarvim.nix
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

  home.packages = with pkgs; [
    fd
    firefox

    (pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; })

    wl-color-picker

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

    # for correct wayland support
    QT_QPA_PLATFORM = "wayland";
    MOZ_ENABLE_WAYLAND = 1;
    GDK_BACKEND = "wayland";
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 18;
  };

  qt.enable = true;

  gtk = {
    enable = true;
    theme = {
      package = pkgs.flat-remix-gtk;
      name = "Flat-Remix-GTK-Grey-Darkest";
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
    };
    theme = "Japanesque"; # "Kaolin Aurora"; # Mayukai
    font = {
      name = "FiraCode Nerd Font Mono";
      package = pkgs.nerdfonts;
      size = 10.0;
    };
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

    initExtra = ''
      bindkey "^[[A" history-beginning-search-backward
      bindkey "^[[B" history-beginning-search-forward
    '';

    historySubstringSearch.enable = true;

    antidote = {
      enable = true;
      plugins = [];
    };
  };

  # prompt
  programs.starship.enable = true;

  # portal - used for programs requesting things from wm, like file picker, screen sharing etc.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    config = {
      common.default = [
        "gtk" # file picker
        "hyprland" # everything
      ];
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  wayland.windowManager.hyprland = let
    mod = "SUPER";
    modshift = "${mod}SHIFT";
    terminal = "kitty";
    xkb = (import ../../nix/i18n.nix {}).config.services.xserver.xkb;
  in {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;

    settings = {
      monitor = [
        "eDP-1, preferred, auto, 1.6"
      ];

      input = {
        kb_layout = xkb.layout;
	      kb_variant = xkb.variant;
      };

      general = {
        gaps_in = 6;
	      gaps_out = 11;
	      border_size = 1;
	      "col.active_border" = "rgba(3472ddee) rgba(fef5fe80) 45deg";
      };

      decoration = {
        rounding = 5;
      };

      misc = {
      };

      input.touchpad.tap-to-click = false;

      bind = [
        "${modshift}, Return, exec, ${terminal}"
        "${modshift}, C,      killactive"
	      "${mod},      F,      exec, firefox"
        # cycle workspaces
	      "${mod},      H,      workspace, -1"
	      "${mod},      L,      workspace, +1"
	      # cycle windows
	      "${mod},      Tab,    cyclenext"
	      "${mod},      Tab,    bringactivetotop"
	      "${modshift}, Tab,    swapnext"
	      # todo: monitors
      ] ++ (
        # workspaces 1..10
	      builtins.concatLists (builtins.genList (
	          x: let
	            key' = if x == 9 then 0 else x + 1;
	            key = builtins.toString key';
	            ws = builtins.toString (x + 1);
	          in [
	            "${mod},      ${key}, workspace, ${ws}"
	            "${modshift}, ${key}, movetoworkspace, ${ws}"
	          ]
	        )
	        10
	      )
      );

      env = [
      ];

      exec-once = [
        "waybar"
      ];
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
