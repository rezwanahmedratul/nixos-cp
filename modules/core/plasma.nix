{ pkgs, lib, ... }:

{
  # X11 / Wayland base support
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # KDE Plasma 6 Desktop Environment
  services.desktopManager.plasma6.enable = true;

  # SDDM Display Manager with Wayland support
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Automatically log in the contest user to KDE Plasma
  services.displayManager.autoLogin = {
    enable = true;
    user = "contestant";
  };

  # Web browser for contest portal access
  programs.firefox.enable = true;
}

