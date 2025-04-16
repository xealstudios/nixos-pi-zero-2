{
  config,
  lib,
  ...
}: {
  options.serialConsole.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable the serial console on the Raspberry Pi.
      This is useful for debugging but should be disabled if peripherals are connected to the serial port
    '';
  };


  config = lib.mkIf config.serialConsole.enable {
    # configure the serial console for boot
    boot.kernelParams = [
      "earlycon"
      "boot.shell_on_fail"
      "8250.nr_uarts=1" # configure mini uart https://forums.raspberrypi.com/viewtopic.php?t=246215
      "console=ttyS0,115200n8"
    ];
    # enable serial console after login
    systemd.services."serial-getty@ttyS0" = lib.mkForce {
      enable = true;
      wantedBy = [];
    };
  };
}