{ inputs, ... }:
{
  flake.modules.homeManager.superpowers =
    { pkgs, lib, ... }:
    let
      ifd = import ../_ifd-safe-skill.nix;
      patchedSuperpowers = pkgs.applyPatches {
        name = "superpowers-patched";
        src = inputs.superpowers;
        patches = [
          "${inputs.self}/patches/superpowers-brainstorming.patch"
          "${inputs.self}/patches/superpowers-writing-plans.patch"
          "${inputs.self}/patches/superpowers-executing-plans.patch"
          "${inputs.self}/patches/superpowers-subagent-driven-dev.patch"
          "${inputs.self}/patches/superpowers-implementer-prompt.patch"
          "${inputs.self}/patches/superpowers-sdd-per-plan-ledger.patch"
          "${inputs.self}/patches/superpowers-task-brief-identifiers.patch"
        ];
      };
    in
    # Install as a stable-named skill entry rather than `plugins`. The HM
    # module's persistent-plugin path names the skills dir after the store
    # basename (`<hash>-superpowers-patched`), so the hash-laden path goes stale
    # on every rebuild that changes the derivation and Claude reports "Plugin
    # directory does not exist". Keying by the attribute name gives a stable
    # `~/.claude/skills/superpowers/` that survives rebuilds — matching how every
    # other skill is installed. Claude still discovers it as the `superpowers`
    # plugin via its `.claude-plugin/plugin.json`, preserving the `superpowers:`
    # namespace. Routed through home.file (not programs.*.skills) because
    # patchedSuperpowers is a derivation; see ../_ifd-safe-skill.nix.
    lib.mkMerge [
      (ifd.claudeSkill "superpowers" "${patchedSuperpowers}")
      (ifd.codexSkill "superpowers" (patchedSuperpowers + "/skills"))
    ];
}
