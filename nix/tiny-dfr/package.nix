{ stdenv, pkgs, inputs }:

let
  pname = "tiny-dfr";
  version = "0.2.0";
  toolchain = inputs.fenix.packages.${pkgs.system}.stable.toolchain;
in
  (pkgs.makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  }).buildRustPackage {
    inherit pname version;
  
    src = pkgs.fetchFromGitHub {
      owner = "WhatAmISupposedToPutHere";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-oawKYrfXAQ5RFMdUCG7F12wHcnFif++44s2KsX9ns6U=";
    };
    cargoSha256 = "sha256-QOkztErJLFXPxCb8MvaXi7jGXeI5A0q8LwZtYddzUZE=";
  
    nativeBuildInputs = with pkgs; [
      pkg-config
    ];
  
    buildInputs = with pkgs; [
      cairo gdk-pixbuf glib libinput libxml2 pango udev 
    ];
  }
