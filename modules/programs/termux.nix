{ ... }:
{
  flake.modules.homeManager.termux =
    { config, pkgs, ... }:
    let
      # Match whatever Nerd Font stylix sets as monospace, no font-specific path.
      # A pattern miss (font swap, or a non-Nerd font) fails the build loudly
      # instead of silently shipping the wrong or missing font.
      fontPattern = "*NerdFontMono-Regular.ttf";
      monoTtf = pkgs.runCommand "termux-font.ttf" { } ''
        # head -1 is a deliberate tie-break: expects one match, takes the first alphabetically otherwise
        src=$(find ${config.stylix.fonts.monospace.package}/share/fonts \
          -iname '${fontPattern}' | sort | head -1)
        if [ -z "$src" ]; then
          echo "no ${fontPattern} under ${config.stylix.fonts.monospace.package}/share/fonts" >&2
          exit 1
        fi
        cp "$src" "$out"
      '';
    in
    {
      # ~/.termux/ mirrors the phone's own dir. Nothing on this host reads it.
      home.file.".termux/font.ttf".source = monoTtf;
      home.file.".termux/termux.properties".source = ./_termux/termux.properties;
    };
}
