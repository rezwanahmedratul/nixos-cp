{ config, pkgs, lib, ... }:

{
  # Enable the X11 windowing system (and Wayland infrastructure)
  services.xserver.enable = true;

  # Enable KDE Plasma 6 Desktop Environment
  services.desktopManager.plasma6.enable = true;

  # Enable SDDM display manager with Wayland support
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Sound architecture (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Web browser for contestants (access to contest portals e.g., Codeforces, AtCoder, DOMjudge)
  programs.firefox.enable = true;

  # dconf support for desktop apps
  programs.dconf.enable = true;

  # Keyboard layout settings (customize as needed)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
