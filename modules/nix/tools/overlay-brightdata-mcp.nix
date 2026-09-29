{ ... }:
{
  # Vendored @brightdata/mcp — Bright Data's Web Unlocker MCP server, built from
  # source so the sandboxed Claude never runs `npx` or fetches from npm at
  # runtime; only the actual Web Unlocker API calls leave the machine. The
  # package is pure ESM with no build step. On upgrade: bump `version`, then
  # refresh both hashes — `src` via
  #   nix-prefetch-url --unpack https://github.com/brightdata/brightdata-mcp/archive/v<version>.tar.gz
  # (then `nix hash to-sri --type sha256 <base32>`), and `npmDepsHash` via
  #   nix run nixpkgs#prefetch-npm-deps -- <unpacked>/package-lock.json
  # Drop this overlay if it ever lands in nixpkgs.
  flake.modules.nixos.overlay-brightdata-mcp =
    { ... }:
    {
      nixpkgs.overlays = [
        (final: _previous: {
          brightdata-mcp = final.buildNpmPackage rec {
            pname = "brightdata-mcp";
            version = "2.11.3";

            src = final.fetchFromGitHub {
              owner = "brightdata";
              repo = "brightdata-mcp";
              rev = "v${version}";
              hash = "sha256-dhskhGbBRZd7yNtyv4TKl+J7EXtqAAB94JtXIsi4VSs=";
            };

            npmDepsHash = "sha256-06xY6dXrBpz+pv+tYq1Kri4c9CPHoV7jGkwaVfl6crE=";

            # Pure ESM — nothing to compile. The package.json `bin` key is a
            # scoped name containing a slash, which npm cannot symlink; drop it,
            # since the MCP wrapper invokes server.js directly (see
            # claude/_internals/mcp.nix).
            dontNpmBuild = true;
            nativeBuildInputs = [ final.jq ];
            # Runs only in the main build, not the npm-deps fetcher derivation
            # (which has a minimal stdenv without our nativeBuildInputs). Strip
            # the slash-bearing scoped `bin` before install-time bin linking.
            preConfigure = ''
              jq 'del(.bin)' package.json > package.json.tmp
              mv package.json.tmp package.json
            '';
          };
        })
      ];
    };
}
