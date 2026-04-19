{ inputs, ... }:

{
  flake.modules.nixos.zvolin = { pkgs, ... }: {
    users.mutableUsers = false;

    users.users.zwolin = {
      isNormalUser = true;
      hashedPasswordFile = "/persist/users/zwolin/password";
      extraGroups = [
        "wheel"
        "wireshark"
        "video"
      ];
      packages = [ ];
      shell = pkgs.zsh;
    };

    nix.extraOptions = ''
      trusted-users = root zwolin
    '';

    home-manager.users.zwolin = {
      imports = with inputs.self.modules.homeManager; [
        browser
        claude
        connman-gui
        audio
        brightness
        direnv
        git
        hypridle
        hyprlock
        keychain
        kitty
        latex
        mako
        terminal
        waybar
        wofi
        zathura
      ];

      home.username = "zwolin";
      home.homeDirectory = "/home/zwolin";
      home.stateVersion = "24.05";

      programs.home-manager.enable = true;
      home.packages = with pkgs; [
        freecad
        gh
        codex
      ];

      home.sessionVariables = {
        XCURSOR_SIZE = "14";
      };

      manual.json.enable = true;
      xdg.enable = true;

      qt.enable = true;
      gtk.enable = true;
      gtk.gtk4.theme = null;
    };
  };
}
