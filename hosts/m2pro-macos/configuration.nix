{ inputs, pkgs, ... }:

{
  imports = with inputs; [
    nixvim.nixDarwinModules.nixvim
    stylix.darwinModules.stylix

    ../../nix/nixvim
    ../../nix/stylix.nix

    # user of this host
    ../../home/users/zvolin-macos
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.settings.experimental-features = "nix-command flakes";

  environment.systemPackages = [ ];

  system.keyboard = {
    enableKeyMapping = true;

    swapLeftCtrlAndFn = true;
    remapCapsLockToEscape = true;
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
