{ inputs, pkgs, ... }:

let
  chvt = "${pkgs.util-linux}/bin/chvt";
in
{
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

      # TODO: doesn't work at all
      # TTY switching workaround - Hyprland doesn't handle XF86Switch_VT_* keysyms
      # xremap intercepts them and runs chvt directly
      keymap = [
        {
          name = "TTY switching";
          remap = builtins.listToAttrs (
            builtins.genList (
              i:
              let
                n = toString (i + 1);
              in
              {
                name = "C-M-F${n}";
                value.launch = [ "${chvt} ${n}" ];
              }
            ) 6
          );
        }
      ];
    };
  };
}
