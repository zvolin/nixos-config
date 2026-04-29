{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
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
    paths = [serenaPackage];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/serena \
        --prefix PATH : ${rustupShim}/bin
    '';
  };

  ferrexPackage = inputs.ferrex.packages.${pkgs.stdenv.hostPlatform.system}.default;

  context7Package = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.context7-mcp;
  mcpNixosPackage = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;

  mcpSearxng = pkgs.buildNpmPackage {
    pname = "mcp-searxng";
    version = "1.0.3";
    src = inputs.mcp-searxng;
    npmDepsHash = "sha256-STrntrJ4k9Gvo+kYUXw/mnC5XyKvzxy28HifCQqostU=";
    nodejs = pkgs.nodejs;
    buildPhase = ''
      npx tsc
    '';
    installPhase = ''
            mkdir -p $out/lib/mcp-searxng $out/bin
            cp -r dist package.json node_modules $out/lib/mcp-searxng/
            cat > $out/bin/mcp-searxng <<EOF
      #!/usr/bin/env bash
      exec ${pkgs.nodejs}/bin/node $out/lib/mcp-searxng/dist/index.js "\$@"
      EOF
            chmod +x $out/bin/mcp-searxng
    '';
  };
in {
  programs.claude-code.mcpServers = {
    serena = {
      command = "${wrappedSerena}/bin/serena";
      args = ["start-mcp-server" "--context" "claude-code" "--project-from-cwd" "--open-web-dashboard" "false"];
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

    context7 = {
      command = "${lib.getExe context7Package}";
    };

    nixos = {
      command = "${lib.getExe mcpNixosPackage}";
    };

    github = {
      command = "${pkgs.writeShellScript "github-mcp-wrapper" ''
        export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-$(${lib.getExe pkgs.gh} auth token)}"
        exec ${lib.getExe pkgs.github-mcp-server} stdio
      ''}";
    };

    searxng = {
      command = "${pkgs.writeShellScript "searxng-mcp-wrapper" ''
        export SEARXNG_URL="http://localhost:8384"
        exec ${mcpSearxng}/bin/mcp-searxng
      ''}";
    };
  };
}
