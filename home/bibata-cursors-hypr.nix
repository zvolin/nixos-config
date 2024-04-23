{ stdenv, pkgs, theme ? "Bibata-Modern-Classic" }:
stdenv.mkDerivation {
  name = "bibata-cursors-hypr";
  version = "0.0.1";
 
  # build dependencies
  bibata_cursors = pkgs.bibata-cursors;
  hyprcursor = pkgs.hyprcursor;
  xcur2png = pkgs.xcur2png;

  # theme name
  theme = theme;
 
  # building
  phases = [ "buildPhase" "installPhase" ];

  buildPhase = ''
    export PATH="$hyprcursor/bin:$xcur2png/bin:$PATH";

    hyprcursor-util \
      --extract "$bibata_cursors"/share/icons/"$theme"/ \
      --output .

    sed -i "s/name = .*/name = ${theme}-Hypr/" *$theme/manifest.hl
  '';
  
  installPhase = ''
    mkdir -p $out/share/icons/
    mv *$theme $out/share/icons/$theme-Hypr
  '';
}
