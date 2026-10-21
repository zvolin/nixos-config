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
        # Authorized-key mesh, one source of truth in the private pubkey map.
        # Trust is asymmetric: a server's authorized set never names the laptop,
        # so a stolen server key gives no foothold back to the daily driver. The
        # concrete edges stay in the private map. mbp-m2 maps to [] (the NixOS
        # default), keeping its authorized-keys closure byte-identical.
        openssh.authorizedKeys.keys = map (
          id: pubKeys.keys.${id}
        ) pubKeys.authorized.${config.networking.hostName};
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

  # Delivers the login password via sops instead of the base aspect's plaintext
  # default. Pure layer on the separately-imported user-headless base; opt-in
  # per host, which must also import user-headless and sops.
  flake.modules.nixos.user-sops =
    { config, ... }:
    {
      imports = with inputs.self.modules.nixos; [ sops ];

      # Key string is a path into encrypted shared.yaml (data), not aspect
      # identity — do not rename it with the aspect.
      sops.secrets."zwolin/hashedPasswordFile" = {
        sopsFile = "${inputs.secrets}/shared.yaml";
        neededForUsers = true; # decrypted before users are created
      };

      users.users.${user}.hashedPasswordFile = config.sops.secrets."zwolin/hashedPasswordFile".path;
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
