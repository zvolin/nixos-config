{ lib, ... }:
{
  # flake-parts defaults raw flake outputs to `unique raw`, so `flake.lib` could
  # otherwise be set in only one module. This explicit mergeable option lets
  # several modules contribute (lan-hosts adds `lanConfig`, alongside the helpers
  # in modules/nix/flake-parts/lib.nix). If a flake-parts change stops flake.lib
  # from merging, eval fails loudly at build time, before any deploy.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Flake-wide lib namespace, mergeable across modules.";
  };
}
