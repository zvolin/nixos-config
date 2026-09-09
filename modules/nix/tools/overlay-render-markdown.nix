{ ... }:
{
  # Vendor render-markdown.nvim's in-review cell-wrapping feature so wide
  # markdown tables inner-wrap (like online viewers) instead of overflowing and
  # breaking the view. Serves as the test bench for contributing the feature
  # upstream. Source is andrewroxby/render-markdown.nvim @ table-wrap-fixes:
  # upstream PR #665 (cell wrapping via virt_lines) plus follow-up fixes for the
  # indent module and two content-hole cases. Pinned by exact revision so the
  # WIP branch cannot shift under us; drop this overlay once the feature merges
  # upstream and lands in nixpkgs.
  flake.modules.nixos.overlay-render-markdown =
    { ... }:
    {
      nixpkgs.overlays = [
        (final: previous: {
          vimPlugins = previous.vimPlugins // {
            render-markdown-nvim = previous.vimPlugins.render-markdown-nvim.overrideAttrs {
              version = "unstable-2026-table-wrap";
              src = final.fetchFromGitHub {
                owner = "andrewroxby";
                repo = "render-markdown.nvim";
                rev = "8f3ed997afd2772062210fe8105c4dca545aafed";
                hash = "sha256-92w4/GTSDg5sqO2et6ZMWLUKvcpDBxvFPNxL3MNwxVA=";
              };
            };
          };
        })
      ];
    };
}
