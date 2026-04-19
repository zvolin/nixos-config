{ ... }:

{
  flake.modules.homeManager.terminal = { pkgs, lib, ... }: {
    options.terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kitty;
      description = "Terminal emulator package used across the desktop";
    };
  };
}
