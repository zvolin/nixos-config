{ lib, pkgs, config, ... }:

{
  programs.wofi = {
    enable = true;

    settings = {
      allow_markup = true;
      width = "35%";
    };
  };
}
