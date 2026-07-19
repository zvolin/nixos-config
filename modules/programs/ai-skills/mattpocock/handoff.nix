{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-handoff =
    { pkgs, ... }:
    let
      patched = pkgs.applyPatches {
        name = "mattpocock-handoff-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-handoff.patch" ];
      };
      skill = patched + "/skills/productivity/handoff";
    in
    {
      programs.claude-code.skills.handoff = skill;
      programs.codex.skills.handoff = skill;
    };
}
