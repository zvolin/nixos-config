{
  inputs,
  lib,
  config,
  ...
}:

{
  imports = with inputs; [
    nix-homebrew.darwinModules.nix-homebrew
    mac-app-util.darwinModules.default
  ];

  options.homebrew-user = lib.mkOption { description = "Name of the user of homebrew"; };

  config = {
    nix-homebrew = {
      # Install Homebrew under the default prefix
      enable = true;

      # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
      enableRosetta = true;

      # User owning the Homebrew prefix
      user = config.homebrew-user;

      # Optional: Declarative tap management
      taps = with inputs; {
        "homebrew/homebrew-core" = homebrew-core;
        "homebrew/homebrew-cask" = homebrew-cask;
        "homebrew/homebrew-bundle" = homebrew-bundle;
      };

      # Enable fully-declarative tap management
      # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
      mutableTaps = false;
    };

    homebrew = {
      enable = true;

      # remove everything not installed by nix
      onActivation.cleanup = "zap";

      # provide nix-homebrew taps so it doesn't try to uninstall those
      taps = builtins.attrNames config.nix-homebrew.taps;
    };
  };
}
