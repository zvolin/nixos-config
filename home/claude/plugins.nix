{ inputs, pkgs, ... }:

let
  patchedSuperpowers = pkgs.applyPatches {
    name = "superpowers-patched";
    src = inputs.superpowers;
    patches = [
      ../../patches/superpowers-brainstorming.patch
      ../../patches/superpowers-writing-plans.patch
      ../../patches/superpowers-executing-plans.patch
      ../../patches/superpowers-subagent-driven-dev.patch
      ../../patches/superpowers-code-quality-reviewer.patch
      ../../patches/superpowers-implementer-prompt.patch
    ];
  };
in
{
  programs.claude-code = {
    plugins = [ patchedSuperpowers ];

    settings = {
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
        "skill-codex@skill-codex" = true;
      };
      extraKnownMarketplaces = {
        skill-codex = {
          source = { source = "github"; repo = "skills-directory/skill-codex"; };
        };
      };
    };
  };
}
