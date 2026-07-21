{ inputs, ... }:
{
  flake.modules.homeManager.superpowers =
    { pkgs, ... }:
    let
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
        ];
      };
    in
    {
      # Install as a stable-named skill entry rather than `plugins`. The HM
      # module's persistent-plugin path names the skills dir after the store
      # basename (`<hash>-superpowers-patched`), so the hash-laden path goes
      # stale on every rebuild that changes the derivation and Claude reports
      # "Plugin directory does not exist". A `skills.<name>` entry uses the
      # attribute name verbatim, giving a stable `~/.claude/skills/superpowers/`
      # that survives rebuilds — matching how every other skill is installed.
      # Claude still discovers it as the `superpowers` plugin via its
      # `.claude-plugin/plugin.json`, preserving the `superpowers:` namespace.
      programs.claude-code.skills.superpowers = "${patchedSuperpowers}";
      programs.codex.skills.superpowers = patchedSuperpowers + "/skills";
    };
}
