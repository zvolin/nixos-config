{ inputs, ... }:
{
  flake.modules.homeManager.ferrex =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      homeDir = config.home.homeDirectory;
      ferrexPackage = inputs.ferrex.packages.${pkgs.stdenv.hostPlatform.system}.default;
      dataDir = "${homeDir}/.local/share/qdrant";
      ferrexSkills = {
        remember = ./files/remember;
        recall = ./files/recall;
        checkpoint = ./files/checkpoint;
        forget = ./files/forget;
        reflect = ./files/reflect;
      };
    in
    {
      programs.claude-code.skills = ferrexSkills;
      programs.codex.skills = ferrexSkills;

      programs.mcp.servers.ferrex = {
        command = "${pkgs.writeShellScript "ferrex-mcp-wrapper" ''
          export FERREX_LOG=info
          export FERREX_LOG_FILE="${homeDir}/.ferrex/ferrex.log"
          exec ${lib.getExe' ferrexPackage "ferrex"} \
            --qdrant-url "http://localhost:6334" \
            --db-path "${homeDir}/.ferrex/ferrex.db"
        ''}";
      };

      systemd.user.services.qdrant = {
        Unit = {
          Description = "Qdrant vector database for ferrex memory";
          After = [ "network.target" ];
        };
        Service = {
          ExecStart = "${pkgs.qdrant}/bin/qdrant --config-path ${pkgs.writeText "qdrant-config.yaml" ''
            service:
              host: 127.0.0.1
              http_port: 6333
              grpc_port: 6334
            storage:
              storage_path: ${dataDir}/storage
              snapshots_path: ${dataDir}/snapshots
            telemetry_disabled: true
          ''}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
}
