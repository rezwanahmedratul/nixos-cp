{ config, pkgs, ... }:

{
  # University Lab Administration User
  users.users.admin = {
    isNormalUser = true;
    description = "Lab Administrator";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "admin"; # Change after initial deployment
    openssh.authorizedKeys.keys = [
      # Add lab administrator SSH public keys here for remote management:
      # "ssh-ed25519 AAAA..."
    ];
  };

  # Allow wheel group to sudo
  security.sudo.wheelNeedsPassword = true;
}

