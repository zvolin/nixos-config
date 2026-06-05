{ inputs, ... }:
{
  flake.modules.homeManager.skill-codex =
    { pkgs, ... }:
    let
      patched = pkgs.applyPatches {
        name = "skill-codex-patched";
        src = inputs.skill-codex;
        patches = [ "${inputs.self}/patches/skill-codex-safe-invocation.patch" ];
      };
    in
    {
      programs.claude-code.plugins = [ "${patched}/plugins/skill-codex" ];
    };
}
