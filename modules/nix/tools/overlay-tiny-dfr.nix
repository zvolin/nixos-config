{ inputs, ... }:

{
  flake.modules.nixos.overlay-tiny-dfr = { ... }: {
    nixpkgs.overlays = [
      (final: previous: {
        tiny-dfr = inputs.tiny-dfr.packages.${final.stdenv.hostPlatform.system}.default;
      })
    ];
  };
}
