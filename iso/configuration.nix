{ pkgs, modulesPath, lib, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ../modules/nixos/contest-environment.nix
    ../modules/nixos/desktop-kde.nix
  ];

  # Allow proprietary packages in the live image
  nixpkgs.config.allowUnfree = true;

  # Enable flakes in the live installer
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Configure live user
  networking.hostName = "contest-live";
  boot.zfs.forceImportRoot = false;

  # Enable contest environment in live ISO
  contest = {
    enable = true;
    user = "nixos"; # Default user on NixOS live ISO
    autoLogin = true;
  };

  # SSH for remote maintenance / deployment
  services.openssh.enable = true;

  system.stateVersion = "26.05";
}
