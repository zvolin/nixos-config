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
    binaryen # various wasm tools, eg. wasm-opt
    bash
    cmake
    curl
    go
    ninja
    pkg-config
    protobuf
    python3
    (rust-bin.stable.latest.default.override {
      targets = [ "wasm32-unknown-unknown" ];
    })
    wasm-pack
    libclang.lib
    llvmPackages.libcxxClang
    clang
    yarn
    nodejs
  ];

  LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
}
