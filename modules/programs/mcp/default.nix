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

      # Pre-built Bright Data Web Unlocker MCP server (no npx, no runtime npm
      # fetch). The jail — shared by Claude and Codex — injects the token as
      # BRIGHTDATA_API_TOKEN; the server reads the generic API_TOKEN, so the
      # wrapper maps it, scoping that name to this child rather than the whole
      # jail env. Defined here (not per-client) so both clients pick it up via
      # enableMcpIntegration.
      brightdataMcp = pkgs.writeShellScript "brightdata-mcp" ''
        export API_TOKEN="''${BRIGHTDATA_API_TOKEN:-}"
        exec ${pkgs.nodejs}/bin/node \
          ${pkgs.brightdata-mcp}/lib/node_modules/@brightdata/mcp/server.js "$@"
      '';
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
          brightdata = {
            command = "${brightdataMcp}";
            # Web Unlocker zone name — not secret. The MCP server auto-creates
            # this zone on first use if absent; change if your zone differs.
            env.WEB_UNLOCKER_ZONE = "mcp_unlocker";
          };
        };
      };
    };
}
