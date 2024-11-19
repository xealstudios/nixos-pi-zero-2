{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    ./sd-image.nix
    ./modules/network/otg.nix
  ];

  # Some packages (ahci fail... this bypasses that) https://discourse.nixos.org/t/does-pkgs-linuxpackages-rpi3-build-all-required-kernel-modules/42509
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  # ! Need a trusted user for deploy-rs.
  nix.settings.trusted-users = ["@wheel"];
  system.stateVersion = "24.05";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  sdImage = {
    # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
    compressImage = false;
    imageName = "zero2.img";

    extraFirmwareConfig = {
      # Give up VRAM for more Free System Memory
      # - Disable camera which automatically reserves 128MB VRAM
      start_x = 0;
      # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
      gpu_mem = 16;

      # Configure display to 800x600 so it fits on most screens
      # * See: https://elinux.org/RPi_Configuration
      hdmi_group = 2;
      hdmi_mode = 8;
    };
  };

  # Keep this to make sure wifi works
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [pkgs.raspberrypiWirelessFirmware];

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi02w;
    kernelParams = [
      "earlycon" # enable writing to uart serial console early in boot process
      "boot.shell_on_fail"
      "8250.nr_uarts=1" # configure mini uart https://forums.raspberrypi.com/viewtopic.php?t=246215
      "console=ttyS0,115200n8" #set console to output to uart1 (miniuart)
    ];
    initrd.availableKernelModules = [
      "xhci_pci" 
      "usbhid" 
      "usb_storage"
      "libcomposite" # For OTG ethernet. See here: https://discourse.nixos.org/t/looking-for-help-to-create-a-raspberry-pi-with-usb-ethernet/27039
      ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    # enable otg usb ethernet
    otg = {
      enable = true;
      module = "ether";
    };

    # Avoids warning: mdadm: Neither MAILADDR nor PROGRAM has been set. This will cause the `mdmon` service to crash.
    # See: https://github.com/NixOS/nixpkgs/issues/254807
    swraid.enable = lib.mkForce false;
  };

  # networking = {
  #   interfaces."wlan0".useDHCP = true;
  #   wireless = {
  #     enable = true;
  #     interfaces = ["wlan0"];
  #     # ! Change the following to connect to your own network
  #     networks = {
  #       "<ssid>" = {
  #         psk = "<ssid-key>";
  #       };
  #     };
  #   };
  # };
  
  # enable OTG Ethernet
  networking.dhcpcd.denyInterfaces = [ "usb0" ];

  services.dhcpd4 = {
    enable = true;
    interfaces = [ "usb0" ];
    extraConfig = ''
      option domain-name "nixos";
      option domain-name-servers 8.8.8.8, 8.8.4.4;
      subnet 10.0.3.0 netmask 255.255.255.0 {
        range 10.0.3.100 10.0.3.200;
        option subnet-mask 255.255.255.0;
        option broadcast-address 10.0.3.255;
      }
    '';
  };

  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.3.1";
    prefixLength = 24;
  }];

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  # NTP time sync.
  services.timesyncd.enable = true;

  # ! Change the following configuration
  users.users.bob = {
    isNormalUser = true;
    home = "/home/bob";
    description = "Bob";
    extraGroups = ["wheel" "networkmanager"];
    # ! Be sure to put your own public key here
    openssh.authorizedKeys.keys = ["a public key"];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  # ! Be sure to change the autologinUser.
  services.getty.autologinUser = "bob";

  # disable zfs and cifs to prevent samba error when cross-compiling
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.supportedFilesystems.cifs = lib.mkForce false;
}
