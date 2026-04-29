{
  # Fix static nettle builds on aarch64: use -fPIC instead of -fpic to avoid
  # GOT overflow when linking qemu-user-static.
  # https://github.com/NixOS/nixpkgs/issues/392673#issuecomment-3004501346
  flake.modules.nixos.overlay-nettle = {lib, ...}: {
    nixpkgs.overlays = [
      (final: previous: {
        nettle = previous.nettle.overrideAttrs (
          lib.optionalAttrs final.stdenv.hostPlatform.isStatic {
            CCPIC = "-fPIC";
          }
        );
      })
    ];
  };
}
