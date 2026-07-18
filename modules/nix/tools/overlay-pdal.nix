{
  # pdal 2.9.3 in nixpkgs 26.11pre1035164 fails to build against gdal's newer
  # CSLConstList API. Fixed upstream by pdal 2.9.3 -> 2.10.2 in
  # https://github.com/NixOS/nixpkgs/pull/541146, but that merged after the
  # channel HEAD we're pinning. Drop this overlay once nixos-unstable advances
  # past the merge.
  flake.modules.nixos.overlay-pdal = {
    nixpkgs.overlays = [
      (final: previous: {
        pdal = previous.pdal.overrideAttrs (old: rec {
          version = "2.10.2";
          src = previous.fetchFromGitHub {
            owner = "PDAL";
            repo = "PDAL";
            tag = version;
            hash = "sha256-VxELHAiiFMKjsvgBK4Cm6YJSrs/4QhhF1haZv4/FlZg=";
          };
          disabledTests = (builtins.filter (t: t != "pdal_io_copc_reader_test") old.disabledTests) ++ [
            "pdal_io_copc_remote_reader_test"
          ];
        });
      })
    ];
  };
}
