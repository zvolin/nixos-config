{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-domain-modeling =
    { pkgs, ... }:
    let
      patched = pkgs.applyPatches {
        name = "mattpocock-domain-modeling-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-domain-modeling.patch" ];
      };
      skill = patched + "/skills/engineering/domain-modeling";
    in
    {
      programs.claude-code.skills.domain-modeling = skill;
      programs.codex.skills.domain-modeling = skill;
    };
}
