{ stdenv, pkgs, bibata-cursors, hyprcursor, xcur2png, theme ? "Bibata-Modern-Classic", ... }:

let
  bibata-cursors-dir = "${pkgs.bibata-cursors}";
in
  stdenv.mkDerivation {
    name = "bibata-cursors-hypr";
    version = "0.0.1";

    # theme name
    theme = theme;

    nativeBuildInputs = [
      bibata-cursors hyprcursor xcur2png
    ];

    # building
    phases = [ "buildPhase" "installPhase" ];

    buildPhase = ''
      hyprcursor-util \
        --extract "${bibata-cursors-dir}"/share/icons/"$theme"/ \
        --output .

      sed -i "s/name = .*/name = ${theme}-Hypr/" *$theme/manifest.hl
    '';

    installPhase = ''
      mkdir -p $out/share/icons/
      mv *$theme $out/share/icons/$theme-Hypr
    '';
  }
