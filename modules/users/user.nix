{ inputs, ... }:
let
  user = "zwolin";
in
{
  # Base identity + the minimal Home-Manager set shared by every host.
  flake.modules.nixos.user-headless =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      pubKeys = inputs.self.lib.hostPubKeys;
    in
    {
      users.mutableUsers = false;

      users.users.${user} = {
        isNormalUser = true;
        # mkDefault so a host can override the password file path.
        hashedPasswordFile = lib.mkDefault "/persist/users/${user}/password";
        extraGroups = [ "wheel" ];
        packages = [ ];
        shell = pkgs.zsh;
      };

      nix.extraOptions = ''
        trusted-users = root ${user}
      '';

      home-manager.users.${user} = {
        imports = with inputs.self.modules.homeManager; [
          git
          direnv
          keychain
        ];

        home.username = user;
        home.homeDirectory = "/home/${user}";
        home.stateVersion = "24.05";

        programs.home-manager.enable = true;

        manual.json.enable = true;
        xdg.enable = true;
      };
    };

  # Desktop layer on the base: GUI groups and the desktop Home-Manager modules.
  # Pure layer; hosts importing this must also import user-headless.
  flake.modules.nixos.user-desktop =
    { lib, pkgs, ... }:
    {
      users.users.${user}.extraGroups = [
        "wireshark"
        "video"
      ];

      home-manager.users.${user} = {
        imports = with inputs.self.modules.homeManager; [
          ai-headless
          audio
          bambu-studio
          brightness
          browser
          connman-gui
          hypridle
          hyprlock
          keychain-desktop
          kitty
          latex
          mako
          orca-slicer
          terminal
          termux
          waybar
          wofi
          zathura
        ];

        home.packages = with pkgs; [
          freecad
          gimp
          pitivi
        ];

        home.sessionVariables = {
          XCURSOR_SIZE = "14";
        };

        # Stylix sets home.pointerCursor.{name,package,size} but not `.enable`.
        home.pointerCursor.enable = true;

        qt.enable = true;
        gtk.enable = true;
        gtk.gtk4.theme = lib.mkForce null;
      };
    };
}
