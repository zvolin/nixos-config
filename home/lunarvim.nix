{ pkgs, ... }:

{
  home.packages = [
    pkgs.lunarvim
    pkgs.gnumake
    pkgs.python3
    pkgs.nodejs_21
    pkgs.cargo
    pkgs.ripgrep
  ];

  home.file.".config/lvim/config.lua".source = /persist/dotfiles/.config/lvim/config.lua;
}
