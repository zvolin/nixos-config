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

          # capslock => ctl | esc
          remap.capslock = {
            held = "ctrl_l";
            alone = "esc";
          };
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
