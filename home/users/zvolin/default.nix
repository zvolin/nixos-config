{ pkgs, inputs, ... }:
{
  # todo?: move to nix/home-manager.nix
  users.mutableUsers = false;
  # configure home manager
  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {
      inherit inputs;
    };
    # use system nixpkgs
    useGlobalPkgs = true;
  };

  users.users.zwolin = {
    isNormalUser = true;
    hashedPasswordFile = "/persist/users/zwolin/password";
    extraGroups = [
      "docker"
      "wheel"
      "wireshark"
    ]; # Enable ‘sudo’ for the user.
    packages = [ ];
    shell = pkgs.zsh;
  };

  # for devenv
  nix.extraOptions = ''
    trusted-users = root zwolin
  '';

  home-manager.users = {
    "zwolin" = import ./home.nix;
  };
}
