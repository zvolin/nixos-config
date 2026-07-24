{ inputs, ... }:
{
  flake.modules.nixos.zvolin =
    { pkgs, lib, ... }:
    {
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
          audio
          brightness
          browser
          claude
          cleanup
          codex
          connman-gui
          direnv
          dissent-review
          git
          humanizer
          hypridle
          hyprlock
          keychain
          kitty
          latex
          mako
          mattpocock-architecture
          mattpocock-domain-modeling
          mattpocock-handoff
          mattpocock-wayfinder
          mcp
          post-implementation-polish
          research
          review
          skill-codex
          superpowers
          terminal
          termux
          threat-modeling-expert
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
          gimp
          pitivi
        ];

        home.sessionVariables = {
          XCURSOR_SIZE = "14";
        };

        # Stylix sets home.pointerCursor.{name,package,size} but not `.enable`;
        # enable it explicitly (the implicit-enable path is deprecated).
        home.pointerCursor.enable = true;

        manual.json.enable = true;
        xdg.enable = true;

        qt.enable = true;
        gtk.enable = true;
        gtk.gtk4.theme = lib.mkForce null;
      };
    };
}
