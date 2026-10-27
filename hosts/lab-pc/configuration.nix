{ config, pkgs, lib, ... }:

{
  imports = [
    ../common/default.nix
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # Hostname for lab machines.
  # Can be overridden or customized per machine (e.g., lab-pc-01, lab-pc-02)
  networking.hostName = lib.mkDefault "lab-pc";

  # NixOS Release State Version - Keep fixed to match install time
  system.stateVersion = "26.05";
}

