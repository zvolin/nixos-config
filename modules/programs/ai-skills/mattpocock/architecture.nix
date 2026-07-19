{ inputs, ... }:
{
  flake.modules.homeManager.mattpocock-architecture =
    { pkgs, ... }:
    let
      patched = pkgs.applyPatches {
        name = "mattpocock-architecture-patched";
        src = inputs.mattpocock-skills;
        patches = [ "${inputs.self}/patches/mattpocock-architecture.patch" ];
      };
      codebaseDesign = patched + "/skills/engineering/codebase-design";
      improveArchitecture = patched + "/skills/engineering/improve-codebase-architecture";
    in
    {
      programs.claude-code.skills.codebase-design = codebaseDesign;
      programs.claude-code.skills.improve-codebase-architecture = improveArchitecture;
      programs.codex.skills.codebase-design = codebaseDesign;
      programs.codex.skills.improve-codebase-architecture = improveArchitecture;
    };
}
