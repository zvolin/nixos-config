{ inputs, ... }:
{
  flake.modules.nixos.asahi =
    { pkgs, lib, ... }:
    {
      imports = [ inputs.nixos-apple-silicon.nixosModules.default ];
      hardware.asahi.enable = true;
      hardware.graphics.enable = true;

      # Apple-only: set the next boot back to macOS, then reboot.
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "reboot-macos" ''
          sudo ${lib.getExe pkgs.asahi-bless} --set-boot-macos --yes
          reboot
        '')
      ];
    };
}
