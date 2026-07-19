{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-wayfinder =
    { pkgs, ... }:
    let
      patched = pkgs.applyPatches {
        name = "mattpocock-wayfinder-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-wayfinder.patch" ];
      };
      skill = patched + "/skills/engineering/wayfinder";
    in
    {
      programs.claude-code.skills.wayfinder = skill;
      programs.codex.skills.wayfinder = skill;
    };
}
