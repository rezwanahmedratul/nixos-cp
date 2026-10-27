{ pkgs, lib, ... }:

{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Prevent /boot partition fill-up
      };
      efi.canTouchEfiVariables = true;
    };
    zfs.forceImportRoot = false;
  };
}

