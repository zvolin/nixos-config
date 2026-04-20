{ inputs, ... }:

{
  flake.modules.nixos.xremap = {
    imports = [ inputs.xremap.nixosModules.default ];

    services.xremap = {
      enable = true;
      config = {
        modmap = [
          {
            name = "Global";

            # swap alt-r and super-r
            remap.super_r = "alt_r";
            remap.alt_r = "super_r";

            # capslock => ctrl
            remap.capslock = "ctrl_l";

            # disable physical ctrl keys to force caps lock usage
            # muhenkan is a Japanese IME key that does nothing on non-JP systems
            remap.ctrl_l = "muhenkan";
            remap.ctrl_r = "muhenkan";
          }
        ];
      };
    };
  };
}
