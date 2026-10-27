{ pkgs, modulesPath, lib, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ../modules/core
  ];

  networking.hostName = "contest-live";

  # Configure live user password fallback
  users.users.nixos.initialPassword = lib.mkDefault "contest";
}
