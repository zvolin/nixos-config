# nix man pages in telescope
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (pkgs.rustPlatform.buildRustPackage rec {
      pname = "manix";
      version = "c532d14b0b59d92c4fab156fc8acd0565a0836af";

      src = fetchFromGitHub {
        owner = "zvolin";
        repo = pname;
        rev = version;
        hash = "sha256-Uo+4/be6rT0W8Z1dvCRXOANvoct6gJ4714flhyFzmKU=";
      };
      cargoHash = "sha256-JGIAqNDMADcfcNwNRm24yBUpB4rV0cVhtw/P3Da/Tyw=";
    })
  ];

  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      telescope-manix
    ];

    extraConfigLua = ''
      require("telescope").load_extension("manix")
    '';
  };
}
