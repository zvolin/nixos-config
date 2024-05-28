{ ... }:

{
  programs.wofi = {
    enable = true;

    settings = {
      allow_markup = true;
      width = "35%";
    };

    style = ''
      window {
        border-radius: 10px;
        font-family: FiraCode Nerd Font;
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
      }

      #entry:selected {
        border-radius: 10px;
      }

      #text {
        padding: 4px 10px;
      }
    '';
  };
}
