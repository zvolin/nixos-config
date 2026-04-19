{ ... }:

{
  flake.modules.nixos.i18n = {
    i18n.defaultLocale = "en_US.UTF-8";

    console = {
      keyMap = "dvorak";
      earlySetup = true;
    };

    services.xserver.xkb = {
      layout = "pl";
      variant = "dvorak";
    };
  };
}
