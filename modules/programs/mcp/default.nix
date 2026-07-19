{ ... }:
{
  flake.modules.homeManager.mcp =
    {
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      context7Package = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.context7-mcp;
      mcpNixosPackage = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      programs.mcp = {
        enable = true;

        # Per-server `required = true` keys pass through the upstream
        # programs.mcp → programs.codex transform unchanged (it strips only
        # `disabled` / `headers`), and Claude Code respects them too — so a
        # broken MCP server fails loud instead of disappearing silently.
        servers = {
          context7 = {
            command = "${lib.getExe context7Package}";
          };
          nixos = {
            command = "${lib.getExe mcpNixosPackage}";
            required = true;
          };
        };
      };
    };
}
