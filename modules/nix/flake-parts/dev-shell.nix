{inputs, ...}: {
  perSystem = {system, ...}: let
    overlays = [(import inputs.rust-overlay)];
    pkgs = import inputs.nixpkgs {inherit system overlays;};
  in {
    devShells.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        binaryen
        bash
        cmake
        curl
        go
        ninja
        pkg-config
        protobuf
        python3
        (lib.hiPrio rust-bin.nightly.latest.rust-analyzer)
        (rust-bin.stable.latest.default.override {
          targets = ["wasm32-unknown-unknown"];
        })
        wasm-pack
        libclang.lib
        llvmPackages.libcxxClang
        clang
        yarn
        nodejs
      ];

      LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    };
  };
}
