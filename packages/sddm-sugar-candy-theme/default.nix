{
  stdenvNoCC,
  fetchFromGitHub,
  libsForQt5,
  themeconf,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "sddm-sugar-candy";
  version = "2b72ef6c6f720fe0ffde5ea5c7c48152e02f6c4f";

  src = fetchFromGitHub {
    owner = "zvolin";
    repo = pname;
    rev = version;
    hash = "sha256-XggFVsEXLYklrfy1ElkIp9fkTw4wvXbyVkaVCZq4ZLU=";
  };

  propagatedUserEnvPkgs = [ libsForQt5.qtgraphicaleffects ];

  patches = [
    # https://framagit.org/MarianArlt/sddm-sugar-candy/-/issues/1
    ./user-selection-box.patch
  ];

  installPhase = ''
    mkdir "$out"
    mv * "$out"

    echo "${themeconf}" > "$out/theme.conf"
  '';
}
