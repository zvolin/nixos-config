{ ... }:

{
  flake.modules.homeManager.latex = { pkgs, ... }: {
    home.packages = [ pkgs.texliveFull ];
  };
}
