{ lib, ... }:

{
  imports = [
    ../../modules/core
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # Set to true for fresh installations from Live USB (Disko manages partitions).
  # Set to false on existing installed systems (hardware-configuration.nix manages filesystems).
  disko.enableConfig = lib.mkDefault true;
}
