{ lib, pkgs, config, ... }:
let
  cfg = config.zwolin;
in
{
  options.zwolin = {
    enable = lib.mkEnableOption "zwolin";
  };

  config = lib.mkIf cfg.enable {
    users.users.zwolin = {
      isNormalUser = true;
      hashedPasswordFile = "/persist/users/zwolin/password";
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      packages = [];
      shell = pkgs.zsh;
    };

    home-manager.users = {
      "zwolin" = import ./home.nix;
    };
  };
}
