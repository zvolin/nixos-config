{...}: {
  flake.modules.homeManager.mcp = {
    inputs,
    lib,
    pkgs,
    ...
  }: let
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

    # Serena's per-client `--context` arg means a single
    # `programs.mcp.servers.serena` entry won't work; build the wrapper here once
    # and share it with both clients via `_module.args.serena`.
    serenaPackage = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.serena;

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

    serena = pkgs.symlinkJoin {
      name = "serena-wrapped";
      paths = [serenaPackage];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/serena \
          --prefix PATH : ${rustupShim}/bin:${pkgs.rust-analyzer}/bin
      '';
    };
  in {
    _module.args.serena = serena;

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
    };
  };
}
