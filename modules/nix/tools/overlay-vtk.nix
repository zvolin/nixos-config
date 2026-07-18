{
  # vtk 9.5.2 in nixpkgs 26.11pre1035164 fails to build against gdal 3.13's
  # new CSLConstList return type in IO/GDAL. Upstream Kitware patch pulled
  # from https://github.com/NixOS/nixpkgs/pull/537721 (issue #542507).
  # Drop this overlay once that PR merges and reaches nixos-unstable.
  flake.modules.nixos.overlay-vtk = {
    nixpkgs.overlays = [
      (final: previous: {
        vtk = previous.vtk.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./vtk-gdal-3.13-const-metadata.patch
          ];
        });
      })
    ];
  };
}
