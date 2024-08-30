{
  system,
  nixpkgs,
  inputs,
}:
let
  overlays = [ (import inputs.rust-overlay) ];
  pkgs = import nixpkgs { inherit system overlays; };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    cmake
    curl
    go
    ninja
    pkg-config
    protobuf
    python3
    rust-bin.stable.latest.default
    wasm-pack
  ];
}
