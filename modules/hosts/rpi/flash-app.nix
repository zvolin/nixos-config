{ inputs, ... }:
{
  # `nix run .#flash-rpi` — build the rpi sd-image and flash it to an SD card in
  # the Steam Deck over SSH, planting the host key before first boot. aarch64
  # only: the only machine that runs this is the Mac, which builds the image
  # natively, and there is no x86_64 host in this config.
  perSystem =
    { system, lib, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };

      # Deck-side flasher: a bare text file (no /nix/store shebang), scp'd and run
      # by the Deck's own bash. SteamOS has no Nix store to resolve a wrapped one.
      remoteFlash = pkgs.writeText "flash-rpi-remote.sh" (builtins.readFile ./_flash/flash-remote.sh);

      flashRpi = pkgs.writeShellApplication {
        name = "flash-rpi";
        runtimeInputs = with pkgs; [
          openssh
          nix
          coreutils
          gnugrep
        ];
        # The store path has no spaces, so the bare assignment is safe; shellcheck
        # then runs over the wrapper plus the appended local script as one unit.
        text = ''
          FLASH_REMOTE_SCRIPT=${remoteFlash}
          export FLASH_REMOTE_SCRIPT
        ''
        + builtins.readFile ./_flash/flash-local.sh;
      };
    in
    # Gate the inner values, not the whole perSystem return: a return wrapped
    # entirely in `optionalAttrs (system == …)` leaves flake-parts unable to
    # statically prove `formatter` is unset for every system, and `nix flake
    # check` fails. Always exposing the `apps`/`packages` keys (empty off-Pi)
    # keeps that static analysis happy.
    {
      apps = lib.optionalAttrs (system == "aarch64-linux") {
        flash-rpi = {
          type = "app";
          program = lib.getExe flashRpi;
          meta.description = "Build the rpi sd-image and flash it to an SD card in the Steam Deck over SSH";
        };
      };
      packages = lib.optionalAttrs (system == "aarch64-linux") {
        flash-rpi = flashRpi;
      };
    };
}
