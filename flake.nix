{
  description = "Nixos config flake";

  inputs = {
    # # keep the same version as apple-silicon for smooth integration and binary cache
    # nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    # nixpkgs.follows = "nixos-apple-silicon/nixpkgs";

    # use latest nixpkgs; asahi kernel will rebuild but everything else is fresh
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
      url = "github:obra/superpowers";
      flake = false;
    };

    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };

    ferrex = {
      url = "github:vaporif/ferrex";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TEMPORARY: no follows — our nixpkgs has broken lupa on aarch64,
    # mcp-nixos's pinned nixpkgs builds fine. Remove when upstream fixes lupa.
    mcp-nixos.url = "github:utensils/mcp-nixos";

    mcp-searxng = {
      url = "github:ihor-sokoliuk/mcp-searxng/v1.0.3";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
