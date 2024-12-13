{ inputs, ... }:

{
  imports = [ inputs.xremap.nixosModules.default ];

  services.xremap.config = {
    modmap = [
      {
        name = "Global";

        # swap alt-r and super-r
        remap.super_r = "alt_r";
        remap.alt_r = "super_r";

        # capslock => ctl | esc
        remap.capslock = {
          held = "ctrl_l";
          alone = "esc";
        };
      }
    ];
  };
}
