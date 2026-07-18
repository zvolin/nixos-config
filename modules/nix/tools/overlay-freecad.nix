{
  # freecad 1.1.1 in nixpkgs at our pinned channel HEAD installs an empty
  # share/thumbnailers/FreeCAD.thumbnailer, and the derivation's postInstall
  # uses `--replace-fail` to patch TryExec=/Exec= lines that aren't there.
  # Upstream nixpkgs bug: https://github.com/NixOS/nixpkgs/issues/542724.
  # Until that's fixed, swap `--replace-fail` for `--replace-warn` so the
  # missing pattern is a warning, not a build failure. Drop this overlay
  # when the upstream fix lands.
  flake.modules.nixos.overlay-freecad =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (final: previous: {
          freecad = previous.freecad.overrideAttrs (old: {
            postInstall = builtins.replaceStrings [ "--replace-fail" ] [ "--replace-warn" ] (
              old.postInstall or ""
            );
          });
        })
      ];
    };
}
