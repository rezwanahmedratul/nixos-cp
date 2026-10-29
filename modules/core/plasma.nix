{ pkgs, lib, config, ... }:

let
  # Applications to pin to the KDE Plasma bottom panel
  pinnedLaunchers = [
    "applications:google-chrome.desktop"
    "applications:firefox.desktop"
    "applications:codeblocks.desktop"
    "applications:code.desktop"
    "applications:Alacritty.desktop"
  ];
  launchersStr = lib.concatStringsSep "," pinnedLaunchers;

  # Script to configure pinned launchers on disk and in the live Plasma session
  setupPanelScript = pkgs.writeShellScriptBin "setup-contest-panel" ''
    #!/usr/bin/env bash
    set -euo pipefail

    LAUNCHERS="${launchersStr}"
    CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    # 1. Update on-disk configuration file if it exists
    if [ -f "$CONFIG_FILE" ]; then
      ${pkgs.python3}/bin/python3 -c "
import re

config_path = '$CONFIG_FILE'
launchers_str = '$LAUNCHERS'

try:
    with open(config_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find applet IDs that have plugin=org.kde.plasma.icontasks or taskmanager
    pattern = re.compile(r'(\[Containments\]\[\d+\]\[Applets\]\[(\d+)\][^\[]*?plugin=org\.kde\.plasma\.(?:icontasks|taskmanager))', re.DOTALL)
    applet_ids = [m.group(2) for m in pattern.finditer(content)]

    modified = False
    for aid in applet_ids:
        sec_header = f'[Applets][{aid}][Configuration][General]'
        if sec_header in content:
            sub_pattern = re.compile(rf'({re.escape(sec_header)}[^\[]*?)(launchers=[^\n]*)', re.DOTALL)
            if sub_pattern.search(content):
                content = sub_pattern.sub(rf'\1launchers={launchers_str}', content, count=1)
                modified = True
            else:
                content = content.replace(sec_header, f'{sec_header}\nlaunchers={launchers_str}')
                modified = True

    # Generic fallback: if any launchers= line exists in the file, update it
    if not modified and 'launchers=' in content:
        content = re.sub(r'launchers=[^\n]*', f'launchers={launchers_str}', content)
        modified = True

    if modified:
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(content)
except Exception:
    pass
" || true
    fi

    # 2. Wait for plasmashell DBus interface and update running panel live
    QDBUS="${pkgs.kdePackages.qttools}/bin/qdbus"
    if [ -x "$QDBUS" ]; then
      for i in {1..20}; do
        if "$QDBUS" org.kde.plasmashell /PlasmaShell &>/dev/null; then
          "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
            var allPanels = panels();
            for (var i = 0; i < allPanels.length; i++) {
                var panel = allPanels[i];
                for (var j = 0; j < panel.widgets().length; j++) {
                    var widget = panel.widgets()[j];
                    if (widget.type === 'org.kde.plasma.icontasks' || widget.type === 'org.kde.plasma.taskmanager') {
                        widget.currentConfigGroup = ['General'];
                        widget.writeConfig('launchers', '$LAUNCHERS');
                        widget.reloadConfig();
                    }
                }
            }
          " 2>/dev/null && break || true
        fi
        sleep 1
      done
    fi
  '';

  # Autostart entry so panel is configured on user login
  autostartDesktop = pkgs.makeDesktopItem {
    name = "contest-panel-setup";
    desktopName = "Contest Panel Setup";
    comment = "Configure bottom panel pinned applications for KDE Plasma";
    exec = "${setupPanelScript}/bin/setup-contest-panel";
    categories = [ "Utility" ];
  };
in
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
    user = config.lab.user;
  };

  # Web browser for contest portal access
  programs.firefox.enable = true;

  # Panel launcher setup script and tools
  environment.systemPackages = [
    setupPanelScript
    pkgs.kdePackages.qttools
  ];

  # System-wide autostart entry for all graphical user sessions
  environment.etc."xdg/autostart/contest-panel-setup.desktop".source =
    "${autostartDesktop}/share/applications/contest-panel-setup.desktop";
}
