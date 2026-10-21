{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-domain-modeling =
    { pkgs, lib, ... }:
    let
      # Vendored skill (applyPatches); routed through home.file to avoid eval-time IFD. See ../_ifd-safe-skill.nix.
      ifd = import ../_ifd-safe-skill.nix;
      patched = pkgs.applyPatches {
        name = "mattpocock-domain-modeling-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-domain-modeling.patch" ];
      };
      skill = patched + "/skills/engineering/domain-modeling";
    in
    lib.mkMerge [
      (ifd.claudeSkill "domain-modeling" skill)
      (ifd.codexSkill "domain-modeling" skill)
    ];
}
