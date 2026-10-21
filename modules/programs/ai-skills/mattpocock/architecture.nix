{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-architecture =
    { pkgs, lib, ... }:
    let
      # Vendored skill (applyPatches); routed through home.file to avoid eval-time IFD. See ../_ifd-safe-skill.nix.
      ifd = import ../_ifd-safe-skill.nix;
      patched = pkgs.applyPatches {
        name = "mattpocock-architecture-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-architecture.patch" ];
      };
      codebaseDesign = patched + "/skills/engineering/codebase-design";
      improveArchitecture = patched + "/skills/engineering/improve-codebase-architecture";
    in
    lib.mkMerge [
      (ifd.claudeSkill "codebase-design" codebaseDesign)
      (ifd.claudeSkill "improve-codebase-architecture" improveArchitecture)
      (ifd.codexSkill "codebase-design" codebaseDesign)
      (ifd.codexSkill "improve-codebase-architecture" improveArchitecture)
    ];
}
