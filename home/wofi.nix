{ lib, pkgs, config, ... }:

{
  programs.wofi = {
    enable = true;

    settings = {
      allow_markup = true;
      width = "35%";
    };

    style = let
      palette = config.colorScheme.palette;
    in ''
      window {
        border-radius: 10px;
        font-family: FiraCode Nerd Font;
        font-size: 12px;
        color: #${palette.base05};
        background-color: #${palette.base00};
      }

      #input {
        border: 0px;
        box-shadow: none;
        padding: 10px;
      }

      #inner-box {
        padding: 10px;
      }

      #outer-box {
        border-radius: 8px;
      }

      #text:selected {
        color: #${palette.base00};
      }

      #entry:selected {
        border-radius: 10px;
        background-color: #${palette.base0E};
      }

      #text {
        padding: 4px 10px;
      }
    '';
  };
}
