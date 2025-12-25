{ lib, inputs, ... }:

{
  nixpkgs.overlays = [
    (final: previous: {
      nettle = previous.nettle.overrideAttrs (
        lib.optionalAttrs final.stdenv.hostPlatform.isStatic {
          CCPIC = "-fPIC";
        }
      );

      # use local tiny-dfr from ~/data/tiny-dfr
      tiny-dfr = inputs.tiny-dfr.packages.aarch64-linux.default;
    })
  ];
}
