{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-handoff =
    { pkgs, lib, ... }:
    let
      # Vendored skill (applyPatches); routed through home.file to avoid eval-time IFD. See ../_ifd-safe-skill.nix.
      ifd = import ../_ifd-safe-skill.nix;
      patched = pkgs.applyPatches {
        name = "mattpocock-handoff-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-handoff.patch" ];
      };
      skill = patched + "/skills/productivity/handoff";
    in
    lib.mkMerge [
      (ifd.claudeSkill "handoff" skill)
      (ifd.codexSkill "handoff" skill)
    ];
}
