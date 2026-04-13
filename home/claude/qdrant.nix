{ config, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  dataDir = "${homeDir}/.local/share/qdrant";
  configFile = pkgs.writeText "qdrant-config.yaml" ''
    service:
      host: 127.0.0.1
      http_port: 6333
      grpc_port: 6334
    storage:
      storage_path: ${dataDir}/storage
      snapshots_path: ${dataDir}/snapshots
    telemetry_disabled: true
  '';
in
{
  systemd.user.services.qdrant = {
    Unit = {
      Description = "Qdrant vector database for ferrex memory";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${pkgs.qdrant}/bin/qdrant --config-path ${configFile}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
