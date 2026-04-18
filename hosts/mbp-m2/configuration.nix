# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = with inputs; [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Auto theming
    stylix.nixosModules.stylix
    # Include home-manager
    home-manager.nixosModules.default
    # Include the necessary packages and configuration for Apple Silicon support
    nixos-apple-silicon.nixosModules.default
    nixvim.nixosModules.nixvim

    ../../nix
    ../../overlays

    ./xremap.nix
    ./searxng.nix

    # user of this host
    ../../home/users/zvolin
  ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  # specify path to peripheral firmware files.
  # this is required for flakes to work.
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  # enable opengl
  hardware.graphics.enable = true;

  nix.settings = {
    # turn on the flakes
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # binary cache for apple silicon
    extra-substituters = [
      "https://nixos-apple-silicon.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };

  # Use the grub EFI boot loader.
  # nixos-apple-silicon layer should make it compatible with uboot automatically
  boot.loader.grub.enable = true;
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0 swap_fn_leftctrl=1
  '';

  networking.hostName = "mbp-m2"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # enable touchbar
  services.tiny-dfr.enable = true;

  # Enable the X11 windowing system (for XWayland support)
  services.xserver.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Enable D-Bus activation for notification daemon
  services.dbus.packages = [ pkgs.mako ];
  programs.sway.enable = true;

  # COSMIC desktop
  # services.desktopManager.cosmic.enable = true;
  # services.displayManager.cosmic-greeter.enable = true;

  # display manager - greetd with tuigreet
  services.greetd =
    let
      tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
      desktops = "${config.services.displayManager.sessionData.desktops}/share";
    in
    {
      enable = true;
      settings.default_session = {
        command = lib.concatStringsSep " " [
          "${tuigreet}"
          "--time"
          "--remember"
          "--remember-user-session"
          "--asterisks"
          "--user-menu"
          "--sessions ${desktops}/wayland-sessions:${desktops}/xsessions"
        ];
        user = "greeter";
      };
    };

  # ensure tuigreet cache directory exists with correct permissions
  systemd.tmpfiles.settings."10-tuigreet" = {
    "/persist/var/cache/tuigreet" = {
      d = {
        user = "greeter";
        group = "greeter";
        mode = "0755";
      };
    };
  };

  environment.variables = {
    # specify correct gpu for wlroots
    WLR_DRM_DEVICES = "/dev/dri/card0";
  };

  # services.logind.settings.Login = {
  #   HandlePowerKey = "ignore"; # short press: no action (Hyprland handles DPMS wake)
  #   HandlePowerKeyLongPress = "poweroff"; # long press: shutdown
  #   HandleLidSwitch = "suspend";
  # };

  # compressed in-memory swap
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # zsh
  programs.zsh.enable = true;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
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
    bat
    curl
    devenv
    dig
    docker-compose
    fd
    fzf
    git
    htop
    jq
    ncdu
    neovim
    openssh
    plymouth
    python3
    # rargs
    ripgrep
    sd
    tmux
    vim
    wget
    (pkgs.writeShellScriptBin "reboot-macos" ''
      sudo ${lib.getExe pkgs.asahi-bless} --set-boot-macos --yes
      reboot
    '')
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Wifi and bluetooth
  services.connman = {
    enable = true;
    wifi.backend = "iwd";
  };

  systemd.tmpfiles.rules = [
    "L /var/lib/connman - - - - /persist/var/lib/connman"
    "L /var/cache/tuigreet - - - - /persist/var/cache/tuigreet"
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };
  # disable ugly x11 ssh pass prompt
  programs.ssh.askPassword = "";

  # containers
  # https://discourse.nixos.org/t/docker-ignoring-platform-when-run-in-nixos/21120
  boot.binfmt.preferStaticEmulators = true;
  boot.binfmt.emulatedSystems = [
    "i386-linux"
    "x86_64-linux"
  ];
  virtualisation = {
    containers.enable = true;

    docker = {
      enable = true;
    };
  };
  programs.wireshark.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.

  # Use the iptables for managing firewall rules
  networking.nftables.enable = false;
  networking.firewall = {
    enable = true;

    # allow packets from the docker bridge interfaces
    # https://github.com/NixOS/nixpkgs/issues/417641#issuecomment-2984475281
    extraCommands = "
      iptables -I nixos-fw 1 -i br+ -j ACCEPT
    ";
    extraStopCommands = "
      iptables -D nixos-fw -i br+ -j ACCEPT
    ";
  };

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
