{
  serena,
  ...
}:
{
  programs.claude-code = {
    enableMcpIntegration = true;

    mcpServers = {
      serena = {
        command = "${serena}/bin/serena";
        args = [
          "start-mcp-server"
          "--context"
          "claude-code"
          "--project-from-cwd"
          "--open-web-dashboard"
          "false"
        ];
        required = true;
      };
    };
  };
}
