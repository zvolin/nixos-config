{ ... }:

{
  flake.modules.nixos.unfree = { lib, ... }: {
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
      ];
  };
}
