{ ... }:

final: prev: {
  kitty = prev.kitty.overrideAttrs rec {
    src = prev.fetchFromGitHub {
      owner = "kovidgoyal";
      repo = "kitty";
      rev = "865aa4bc24d6af20deb07041fe6b94e769ea6491";
      hash = "sha256-UMXVFCgWpn1dd72alpHyTc1F8YbBgFJoSJMZeF3iNlo=";
    };
    goModules =
      (prev.buildGo123Module {
        pname = "kitty-go-modules";
        inherit src;
        version = "0.36.4";
        vendorHash = "sha256-d5jRhOm53HDGnsU5Lg5tVGU/9z8RGqORzS53hOyIKBk=";
      }).goModules;
  };
}
