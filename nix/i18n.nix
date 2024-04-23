{ ... }:

{
  imports = [
  ];

  options = {
  };

  config = rec {
    # set locale
    i18n.defaultLocale = "en_US.UTF-8";
    
    # configure keymap for boot and tty
    console = {
      keyMap = "dvorak";
      earlySetup = true;
      # font = "Lat2-Terminus16";
      # useXkbConfig = true; # use xkb.options in tty.
    };

    # configure keymap in X11
    services.xserver.xkb = {
      layout = "pl";
      variant = "dvorak";
    };
  };
}
