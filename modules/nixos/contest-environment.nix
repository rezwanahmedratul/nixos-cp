{ config, pkgs, lib, ... }:

let
  cfg = config.contest;

  # Script to reset workspace between contests
  resetScript = pkgs.writeShellScriptBin "reset-contest-workspace" ''
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET_USER="${cfg.user}"
    USER_HOME="/home/$TARGET_USER"

    echo "=== Competitive Programming Environment Reset ==="
    if [ "$(id -u)" -ne 0 ] && [ "$(whoami)" != "$TARGET_USER" ]; then
      echo "Error: Must be run as root or as $TARGET_USER" >&2
      exit 1
    fi

    echo "Cleaning up temporary files and contest workspace..."
    rm -rf "$USER_HOME/workspace"/* "$USER_HOME/workspace"/.* 2>/dev/null || true
    mkdir -p "$USER_HOME/workspace"

    # Reset browser profile caches
    rm -rf "$USER_HOME/.cache/mozilla" "$USER_HOME/.cache/google-chrome" "$USER_HOME/.cache/chromium" 2>/dev/null || true

    # Reset IDE temporary workspaces
    rm -rf "$USER_HOME/.codeblocks" "$USER_HOME/.config/Code/User/workspaceStorage" 2>/dev/null || true

    # Ensure correct ownership
    if [ "$(id -u)" -eq 0 ]; then
      chown -R "$TARGET_USER:users" "$USER_HOME/workspace"
    fi

    echo "Reset complete. Clean workspace ready at $USER_HOME/workspace"
  '';

  # Desktop item for quick offline C++ documentation
  cpprefDesktop = pkgs.makeDesktopItem {
    name = "cppreference";
    desktopName = "C++ Reference (Offline)";
    comment = "Offline C++ Standard Library Reference";
    exec = "xdg-open /run/current-system/sw/share/doc/cppreference/reference/en/index.html";
    icon = "help-browser";
    categories = [ "Development" "Documentation" ];
  };

  # Desktop item for resetting contest workspace
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
  options.contest = {
    enable = lib.mkEnableOption "Competitive Programming Contest Environment";

    user = lib.mkOption {
      type = lib.types.str;
      default = "contestant";
      description = "Dedicated username for contestants";
    };

    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically log in the contest user on boot";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to include in the contest environment";
    };
  };

  config = lib.mkIf cfg.enable {
    # ---------------------------------------------------------
    # Contestant User Account
    # ---------------------------------------------------------
    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "Contestant";
      extraGroups = [ "networkmanager" "video" "audio" ];
      # Contestant user has no sudo / wheel access to prevent tampering
      initialPassword = lib.mkDefault "contest";
    };

    # Auto-login to display manager (SDDM / Plasma)
    services.displayManager.autoLogin = lib.mkIf cfg.autoLogin {
      enable = true;
      user = cfg.user;
    };

    # ---------------------------------------------------------
    # Contestant Toolchain & Applications
    # ---------------------------------------------------------
    environment.systemPackages = with pkgs; [
      # IDEs and Text Editors
      codeblocks
      vscode
      vscodium
      geany
      kdePackages.kate
      vim
      neovim

      # C & C++ Compiler Toolchain & Debugging
      gcc
      gdb
      clang
      clang-tools
      cmake
      gnumake
      valgrind
      lldb

      # Python Toolchain (CP frequently benefits from PyPy3)
      python3
      pypy3

      # Java Toolchain (Standard ICPC LTS version)
      jdk21

      # JavaScript / Node.js Toolchain
      nodejs

      # Rust Toolchain
      rustc
      cargo

      # Go Toolchain
      go

      # Benchmarking, Diffing & Verification Tools
      time             # GNU time with memory/CPU breakdown (-v)
      diffutils        # diff, cmp
      patch
      file
      tree
      jq
      zip
      unzip
      curl
      wget
      git
      fastfetch
      htop

      # Documentation
      man-pages
      man-pages-posix
      cppreference-doc

      # Essential KDE Applications
      kdePackages.konsole
      kdePackages.dolphin
      kdePackages.kcalc
      kdePackages.ark

      # Custom contest launchers & utilities
      resetScript
      resetDesktop
      cpprefDesktop
    ] ++ cfg.extraPackages;

    # ---------------------------------------------------------
    # Developer Documentation
    # ---------------------------------------------------------
    documentation.enable = true;
    documentation.man.enable = true;
    documentation.dev.enable = true;

    # ---------------------------------------------------------
    # Monospace & Coding Fonts
    # ---------------------------------------------------------
    fonts.packages = with pkgs; [
      fira-code
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];

    # ---------------------------------------------------------
    # Contest Stability & Anti-Disruption Settings
    # ---------------------------------------------------------
    # Prevent system from going to sleep / hibernating during long thinking pauses
    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };

    # NTP time synchronization (crucial for exact contest synchronization)
    services.timesyncd.enable = true;

    # Pre-create workspace directory for contestant
    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/workspace 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/Desktop 0755 ${cfg.user} users -"
    ];
  };
}
