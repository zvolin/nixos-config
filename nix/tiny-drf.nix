{ lib, pkgs, config, inputs, ... }:

{
  options.services.tiny-drf.enable = lib.mkEnableOption "tiny-drf";

  config = {
    # create a systemd service for tiny-drf
    systemd.services.tiny-dfr = {
      description = "Tiny Apple silicon touch bar daemon";
      after = [
        "getty@tty1.service"
      ];
      before = [
        "desktop-manager.service"
      ];
      startLimitIntervalSec = 30;
      startLimitBurst = 2;

      serviceConfig = {
        Restart = "always";
        ExecStart = "${inputs.tiny-dfr.packages.${pkgs.system}.default}/bin/tiny-dfr";
      };
    };

    # https://github.com/itsnebulalol/nixfiles/blob/main/modules/services/tiny-dfr/default.nix
    services.udev.extraRules = ''
      SUBSYSTEM=="backlight", KERNEL=="228200000.display-pipe.0", DRIVERS=="panel-summit", ENV{SYSTEMD_READY}="0"

      SUBSYSTEM=="drm", KERNEL=="card*", DRIVERS=="adp", TAG-="master-of-seat", ENV{ID_SEAT}="seat-touchbar"

      SUBSYSTEM=="input", ATTR{name}=="MacBookPro17,1 Touch Bar", ENV{ID_SEAT}="seat-touchbar"
      SUBSYSTEM=="input", ATTR{name}=="Mac14,7 Touch Bar", ENV{ID_SEAT}="seat-touchbar"

      SUBSYSTEM=="input", ATTR{name}=="MacBookPro17,1 Touch Bar", TAG+="systemd", ENV{SYSTEMD_WANTS}="tiny-dfr.service"
      SUBSYSTEM=="input", ATTR{name}=="Mac14,7 Touch Bar", TAG+="systemd", ENV{SYSTEMD_WANTS}="tiny-dfr.service"
    '';

    # todo, check if that's needed
    boot.kernelPatches = [
      {
        name = "touch";
        patch = null;
        extraConfig = ''
          INPUT_TOUCHSCREEN y
        '';
      }
    ];
  };
}
