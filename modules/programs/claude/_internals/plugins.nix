{ inputs, pkgs, ... }:

let
  patchedSuperpowers = pkgs.applyPatches {
    name = "superpowers-patched";
    src = inputs.superpowers;
    patches = [
      "${inputs.self}/patches/superpowers-brainstorming.patch"
      "${inputs.self}/patches/superpowers-writing-plans.patch"
      "${inputs.self}/patches/superpowers-executing-plans.patch"
      "${inputs.self}/patches/superpowers-subagent-driven-dev.patch"
      "${inputs.self}/patches/superpowers-code-quality-reviewer.patch"
      "${inputs.self}/patches/superpowers-implementer-prompt.patch"
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
