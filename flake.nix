{
  description = "Nixos config flake";

  inputs = {
    # Track latest nixpkgs directly. The nixos-apple-silicon binary cache was
    # dropped upstream on 2026-07-19 (migrating to Hydra, see nixos-hardware#854),
    # so following asahi's nixpkgs no longer yields kernel cache hits; the asahi
    # kernel builds locally regardless.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    xremap = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tiny-dfr = {
      url = "path:/home/zwolin/data/tiny-dfr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    superpowers = {
      url = "github:obra/superpowers/d884ae04edebef577e82ff7c4e143debd0bbec99";
      flake = false;
    };

    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };

    claude-rules = {
      url = "github:lifedever/claude-rules/6d5f8bd62c2d96ca2e07c0c7b8159f75fd2323b6";
      flake = false;
    };

    wshobson-agents = {
      url = "github:wshobson/agents";
      flake = false;
    };

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Flatpak (--user) installs. nix-flatpak declares no inputs of its
    # own, so there is nothing to `follows` — add it plainly.
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # TEMPORARY: no follows — our nixpkgs has broken lupa on aarch64,
    # mcp-nixos's pinned nixpkgs builds fine. Remove when upstream fixes lupa.
    mcp-nixos.url = "github:utensils/mcp-nixos";

    skill-codex = {
      url = "github:skills-directory/skill-codex/0cce7fc7c49b08fd60ae05bdf7934590d7bc34b5";
      flake = false;
    };

    # mattpocock skills, vendored + patched like superpowers. Pinned to a rev;
    # to bump: change the rev, rebuild, regenerate any patch that fails to apply.
    mattpocock-skills = {
      url = "github:mattpocock/skills/9603c1c";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
