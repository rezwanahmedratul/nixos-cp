{ pkgs, lib, ... }:

{
  networking = {
    hostName = lib.mkDefault "lab-pc";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ]; # Allow SSH for lab administrator maintenance
    };
  };

  # Prevent NetworkManager-wait-online from blocking boot
  systemd.services.NetworkManager-wait-online.enable = false;
}
