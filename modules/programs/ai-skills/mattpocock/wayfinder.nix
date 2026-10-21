{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-wayfinder =
    { pkgs, lib, ... }:
    let
      # Vendored skill (applyPatches); routed through home.file to avoid eval-time IFD. See ../_ifd-safe-skill.nix.
      ifd = import ../_ifd-safe-skill.nix;
      patched = pkgs.applyPatches {
        name = "mattpocock-wayfinder-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-wayfinder.patch" ];
      };
      skill = patched + "/skills/engineering/wayfinder";
    in
    lib.mkMerge [
      (ifd.claudeSkill "wayfinder" skill)
      (ifd.codexSkill "wayfinder" skill)
    ];
}
