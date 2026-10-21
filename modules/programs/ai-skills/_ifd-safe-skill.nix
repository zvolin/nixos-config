# Wire a derivation-backed skill into a client's skills directory through
# `home.file`, deliberately bypassing `programs.claude-code.skills` and
# `programs.codex.skills`.
#
# Why the bypass exists
# ---------------------
# Both upstream Home-Manager modules choose "symlink a directory" vs "wrap a lone
# SKILL.md" by probing the skill source with `lib.pathIsDirectory` at evaluation
# time (home-manager: modules/programs/claude-code/lib.nix and
# modules/programs/codex/lib.nix, `mkSkillEntry`). When the source is an
# unrealised derivation output — our vendored skills come from `applyPatches`
# (superpowers, mattpocock) and `runCommand` (threat-modeling-expert) — that
# probe forces the derivation to build during evaluation (import-from-derivation).
# Evaluating an x86_64 host (`nas`) on this aarch64 machine then triggers an x86
# build mid-eval: qemu segfaults, or an off-box build whose copy-back trips the
# store-trust check. `home.file` instead takes the directory as a plain
# build-time closure dependency — the recursive walk runs in the `home-files`
# builder (`lndir`), and `sourceStorePath` short-circuits on context paths, so
# nothing touches the source at eval. Evaluation stays architecture-independent,
# and a single `nixos-anywhere --flake .#nas` redeploys the full host from the Mac.
#
# Parity
# ------
# These helpers reproduce exactly what the upstream `mkSkillEntry` emits for a
# directory source, verified against mbp-m2's evaluated `home.file`:
#   claude -> `.claude/skills/<name>`, source = <dir>, recursive = true
#   codex  -> `.codex/skills/<name>`,  source = <dir>  (recursive defaults false)
# So on a host that builds natively (mbp-m2) the generated files and the closure
# stay byte-identical. The target directories are pinned to the non-XDG layout
# this configuration uses; a Home-Manager bump that moves them (or that flips
# `useXdgDirectories`) must update these two paths in lockstep.
{
  claudeSkill = name: source: {
    home.file.".claude/skills/${name}" = {
      inherit source;
      recursive = true;
    };
  };

  codexSkill = name: source: {
    home.file.".codex/skills/${name}".source = source;
  };
}
