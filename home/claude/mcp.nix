{ config, inputs, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;

  serenaPackage = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.serena;

  # Serena expects rustup for rust-analyzer discovery; shim translates to direct PATH lookup
  rustupShim = pkgs.writeShellScriptBin "rustup" ''
    if [ "$1" = "which" ] && [ "$2" = "rust-analyzer" ]; then
      command -v rust-analyzer
    elif [ "$1" = "run" ] && [ -n "$2" ] && [ "$3" = "rust-analyzer" ]; then
      shift 3
      exec rust-analyzer "$@"
    else
      echo "rustup shim: unsupported invocation: $*" >&2
      exit 1
    fi
  '';

  wrappedSerena = pkgs.symlinkJoin {
    name = "serena-wrapped";
    paths = [ serenaPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/serena \
        --prefix PATH : ${rustupShim}/bin
    '';
  };

  ferrexPackage = inputs.ferrex.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  programs.claude-code.mcpServers = {
    serena = {
      command = "${wrappedSerena}/bin/serena";
      args = [ "start-mcp-server" "--context" "claude-code" "--project-from-cwd" ];
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
}
