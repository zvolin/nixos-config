{...}: {
  flake.modules.homeManager.wofi = {...}: {
    programs.wofi = {
      enable = true;

      settings = {
        allow_markup = true;
        width = "35%";
      };
    };
  };
}
