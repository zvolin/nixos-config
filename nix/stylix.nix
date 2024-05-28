{ pkgs, ... }:

let
  inputImage = ../home/wallpapers/aurora-night-sky.jpg;
  brightness = "-9";
  contrast = "6";
in {
  stylix = {
    image = pkgs.runCommand "wallpaper.png" { } ''
      ${pkgs.imagemagick}/bin/convert "${inputImage}" -brightness-contrast ${brightness},${contrast} $out
    '';
    polarity = "dark";
    base16Scheme = {
      scheme = "Catppuccin Mocha (Darker)";
      author = "https://github.com/catppuccin/catppuccin";
      base00 = "#111120"; # base - modified
      base01 = "#0e0e1d"; # mantle - modified
      base02 = "#313244"; # surface0
      base03 = "#45475a"; # surface1
      base04 = "#585b70"; # surface2
      base05 = "#cdd6f4"; # text
      base06 = "#f5e0dc"; # rosewater
      base07 = "#b4befe"; # lavender
      base08 = "#f38ba8"; # red
      base09 = "#fab387"; # peach
      base0A = "#f9e2af"; # yellow
      base0B = "#a6e3a1"; # green
      base0C = "#94e2d5"; # teal
      base0D = "#89b4fa"; # blue
      base0E = "#cba6f7"; # mauve
      base0F = "#f2cdcd"; # flamingo
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 15;
    };

    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override { fonts = ["FiraCode"]; };
        name = "FiraCode Nerd Font";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sizes = {
        applications = 10;
        terminal = 10;
        desktop = 8;
        popups = 8;
      };
    };
  };
}
