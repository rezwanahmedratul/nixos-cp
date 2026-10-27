{ pkgs, ... }:

let
  # Workspace reset script for contestants / invigilators
  resetScript = pkgs.writeShellScriptBin "reset-contest-workspace" ''
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET_USER="contestant"
    USER_HOME="/home/$TARGET_USER"

    echo "=== Competitive Programming Environment Reset ==="
    if [ "$(id -u)" -ne 0 ] && [ "$(whoami)" != "$TARGET_USER" ]; then
      echo "Error: Must be run as root or as $TARGET_USER" >&2
      exit 1
    fi

    echo "Cleaning up temporary files and contest workspace..."
    rm -rf "$USER_HOME/workspace"/* "$USER_HOME/workspace"/.* 2>/dev/null || true
    mkdir -p "$USER_HOME/workspace"

    # Reset browser caches
    rm -rf "$USER_HOME/.cache/mozilla" "$USER_HOME/.cache/google-chrome" "$USER_HOME/.cache/chromium" 2>/dev/null || true

    # Reset IDE temporary workspaces
    rm -rf "$USER_HOME/.codeblocks" "$USER_HOME/.config/Code/User/workspaceStorage" 2>/dev/null || true

    if [ "$(id -u)" -eq 0 ]; then
      chown -R "$TARGET_USER:users" "$USER_HOME/workspace"
    fi

    echo "Reset complete. Clean workspace ready at $USER_HOME/workspace"
  '';

  # Desktop launcher for offline C++ documentation
  cpprefDesktop = pkgs.makeDesktopItem {
    name = "cppreference";
    desktopName = "C++ Reference (Offline)";
    comment = "Offline C++ Standard Library Reference";
    exec = "xdg-open /run/current-system/sw/share/doc/cppreference/reference/en/index.html";
    icon = "help-browser";
    categories = [ "Development" "Documentation" ];
  };

  # Desktop launcher for workspace reset
  resetDesktop = pkgs.makeDesktopItem {
    name = "reset-contest";
    desktopName = "Reset Contest Workspace";
    comment = "Clean and prepare workspace for next contest round";
    exec = "reset-contest-workspace";
    icon = "system-reboot";
    categories = [ "System" "Utility" ];
    terminal = true;
  };
in
{
  environment.systemPackages = [
    resetScript
    cpprefDesktop
    resetDesktop
  ];

  # Pre-create contestant workspace folders
  systemd.tmpfiles.rules = [
    "d /home/contestant/workspace 0755 contestant users -"
    "d /home/contestant/Desktop 0755 contestant users -"
  ];
}

