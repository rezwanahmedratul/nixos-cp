{ config, pkgs, lib, ... }:

{
  imports = [
    ./users.nix
    ../../modules/nixos/contest-environment.nix
    ../../modules/nixos/desktop-kde.nix
  ];

  # ---------------------------------------------------------
  # Bootloader (systemd-boot with generation limit)
  # ---------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10; # Avoid filling up /boot
  boot.loader.efi.canTouchEfiVariables = true;
  boot.zfs.forceImportRoot = false;

  # ---------------------------------------------------------
  # Networking
  # ---------------------------------------------------------
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # Allow SSH for administrative maintenance
  };

  # ---------------------------------------------------------
  # Remote Administration (SSH)
  # ---------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true; # Enable key-based or password login for admin
    };
  };

  # ---------------------------------------------------------
  # Nix Package Manager & Store Maintenance
  # ---------------------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    auto-optimise-store = true;
  };

  # Automatic Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Allow proprietary packages (VS Code, etc.)
  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------
  # Localization & Timezone
  # ---------------------------------------------------------
  time.timeZone = lib.mkDefault "UTC"; # Adjust to lab timezone (e.g., "Asia/Dhaka", "America/New_York")
  i18n.defaultLocale = "en_US.UTF-8";

  # ---------------------------------------------------------
  # Enable Competitive Programming Contest Environment
  # ---------------------------------------------------------
  contest.enable = true;
  contest.user = "contestant";
  contest.autoLogin = true;
}
