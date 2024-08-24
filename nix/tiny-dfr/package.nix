{
  pkgs, makeRustPlatform, pkg-config, cairo, gdk-pixbuf, glib, libinput,
  libxml2, pango, udev, inputs
}:

let
  pname = "tiny-dfr";
  version = "0.2.0";
  toolchain = inputs.fenix.packages.${pkgs.system}.stable.toolchain;
in
  (makeRustPlatform {
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
    cargoHash = "sha256-QOkztErJLFXPxCb8MvaXi7jGXeI5A0q8LwZtYddzUZE=";

    postPatch = ''
      substituteInPlace src/*.rs --replace /usr/share $out/share
      substituteInPlace etc/systemd/system/tiny-dfr.service --replace /usr/bin $out/bin
    '';

    postInstall = ''
      mv etc "$out/lib"
      mv share "$out"
    '';

    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ cairo gdk-pixbuf glib libinput libxml2 pango udev ];
  }
