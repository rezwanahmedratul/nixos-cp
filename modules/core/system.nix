{ pkgs, lib, ... }:

{
  # Nix package manager features and store optimization
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    auto-optimise-store = true;
  };

  # Automatic weekly garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Allow proprietary packages (e.g. Visual Studio Code)
  nixpkgs.config.allowUnfree = true;

  # Localization and time
  time.timeZone = lib.mkDefault "UTC"; # Adjust to lab timezone
  i18n.defaultLocale = "en_US.UTF-8";

  # NixOS state version
  system.stateVersion = "26.05";
}
