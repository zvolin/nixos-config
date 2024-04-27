# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Include the necessary packages and configuration for Apple Silicon support
    ./apple-silicon-support
    # Include home-manager
    inputs.home-manager.nixosModules.default
    # include common configuration
    ../../nix/default.nix
  ];

  # hardware.asahi.enable = true;
  # specify path to peripheral firmware files.
  # this is required for flakes to work.
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  # use experimental GPU driver
  hardware.asahi.useExperimentalGPUDriver = true;
  # replace the mesa driver with Asahi mesa
  hardware.asahi.experimentalGPUInstallMode = "overlay";
  # build kernel with Rust support
  hardware.asahi.withRust = true;
  # enable opengl
  hardware.opengl.enable = true;
  hardware.opengl.driSupport.enable = true;
  # hardware.opengl.driSupport32Bit = true;


  # turn on the flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0 swap_fn_leftctrl=1
  '';

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # enable touchbar
  services.tiny-drf.enable = true;

  # Enable the X11 windowing system (for XWayland support)
  services.xserver.enable = true;

  # use sddm for display manager
  programs.hyprland.enable = true;
  programs.sway.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  environment.sessionVariables = {
    # specify correct gpu for wlroots
    WLR_DRM_DEVICES = "/dev/dri/card0";
  };
  
  # zsh
  programs.zsh.enable = true;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Erase Your Darlings
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /mnt                                         # create /mnt dir in case it's not present
    mount -t btrfs /dev/mapper/nixos /mnt              # mount the btrfs filesystem
    btrfs subvolume list /mnt |                        # list all subvolumes
    awk -F/ '{print NF-1 " " $0}' |                    # prefix them with the count of '/' in path
    awk '{print $1 " " $NF}' |                         # strip everything but count and subvolume path
    sort -r |                                          # sort subvolumes by depth, decreasing
    cut -d' ' -f 2 |                                   # drop the count
    grep '^root' | grep -v '^root-blank' |             # we only care about removing root subvolumes but without root-blank snapshot
    xargs -I {} btrfs subvolume delete /mnt/{}         # remove all the root subvolumes
    btrfs subvolume snapshot /mnt/root-blank /mnt/root # restore the empty snapshot
  '';

  environment.etc = {
    # persist nixos configuration
    "nixos".source = "/persist/etc/nixos";

    # machine-id is used by systemd for the journal.
    # it must be persisted in order to use journalctl for logs from past boots
    "machine-id".source = "/persist/etc/machine-id";
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    neovim
    openssh
    rargs
    ripgrep
    tmux
    vim
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Wifi and bluetooth
  services.connman = {
    enable = true;
    wifi.backend = "iwd";
  };
  systemd.tmpfiles.rules = [
    "L /var/lib/connman - - - - /persist/var/lib/connman"
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # can't be used with flakes
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
