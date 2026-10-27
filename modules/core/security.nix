{ pkgs, ... }:

{
  # Require password for sudo commands
  security.sudo.wheelNeedsPassword = true;

  # Enable dconf for GTK/desktop application state management
  programs.dconf.enable = true;
}
