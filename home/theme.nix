{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];

  wayland.windowManager.hyprland.settings = let
    palette = config.colorScheme.palette;
  in {
    # set wallpaper
    exec-once = [
      "swaybg -o '*' -m fill -i ${./wallpapers/torii-shrine-gate.jpg}"
    ];
    # set window borders
    general."col.active_border" = "rgba(${palette.base0E}dd) rgba(${palette.base0E}55) 45deg";
  };

  # configure cursor
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 18;
  };

  # gtk theming
  gtk = {
    font = {
      name = "Sans";
      size = 11;
    };
    theme = {
      package = pkgs.flat-remix-gtk;
      name = "Flat-Remix-GTK-Blue-Darkest";
    };
    iconTheme = {
      package = pkgs.gnome.adwaita-icon-theme;
      name = "Adwaita";
    };
  };

  # vim styling
  programs.nixvim.opts.background = "dark";
  programs.nixvim.colorschemes.kanagawa.enable = true;
  programs.nixvim.colorschemes.kanagawa.settings.background.dark = "dragon";

  # kitty styling
  programs.kitty = {
    theme = "Kanagawa_dragon";
    font = {
      name = "FiraCode Nerd Font Mono";
      package = pkgs.nerdfonts;
      size = 10.0;
    };
  };

  # some custom colorscheme to use here and there
  colorScheme = {
    slug = "kanagawa-dragon";
    name = "kanagawa-dragon";
    author = "rebelot";
    palette = {
      base00 = "#0d0c0c";
      base01 = "#12120f";
      base02 = "#282727";
      base03 = "#7a8382";
      base04 = "#393836";
      base05 = "#c5c9c5";
      base06 = "#625e5a";
      base07 = "#b6927b";
      base08 = "#b98d7b";
      base09 = "#9e9b93";
      base0A = "#8ba4b0";
      base0B = "#c4746e";
      base0C = "#8ea4a2";
      base0D = "#737c73";
      base0E = "#949fb5";
      base0F = "#c4b28a";
    };
  };
}
