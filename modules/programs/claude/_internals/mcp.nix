{
  config,
  inputs,
  lib,
  pkgs,
  serena,
  ...
}: let
  homeDir = config.home.homeDirectory;
  ferrexPackage = inputs.ferrex.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  programs.claude-code = {
    enableMcpIntegration = true;

    mcpServers = {
      serena = {
        command = "${serena}/bin/serena";
        args = ["start-mcp-server" "--context" "claude-code" "--project-from-cwd" "--open-web-dashboard" "false"];
        required = true;
      };

      ferrex = {
        command = "${pkgs.writeShellScript "ferrex-mcp-wrapper" ''
          export FERREX_LOG=info
          export FERREX_LOG_FILE="${homeDir}/.ferrex/ferrex.log"
          exec ${lib.getExe' ferrexPackage "ferrex"} \
            --qdrant-url "http://localhost:6334" \
            --db-path "${homeDir}/.ferrex/ferrex.db"
        ''}";
      };
    };
  };
}
