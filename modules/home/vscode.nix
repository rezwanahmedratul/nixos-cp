{
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs.lib) attrByPath;

  # Versions
  codeRunnerVer = "0.12.2";
  cppExtsThemesVer = "2.0.0";
  cppExtsDevToolsVer = "0.5.13";

  # Helper function
  extOrMarketplace = {
    publisher,
    name,
    version ? null,
    sha256 ? null,
  }: let
    fromOpenVSX = attrByPath [publisher name] null pkgs.vscode-extensions;
  in
    if fromOpenVSX != null
    then [fromOpenVSX]
    else if version == null
    then []
    else
      pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          inherit name publisher version;
          sha256 =
            if sha256 == null
            then pkgs.lib.fakeSha256
            else sha256;
        }
      ];


  # codeRunnerExts = extOrMarketplace {
  #   publisher = "formulahendry";
  #   name = "code-runner";
  #   version = codeRunnerVer;
  #   sha256 = pkgs.lib.fakeSha256;
  # };

  cppExtraExts = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "cpptools-themes";
      publisher = "ms-vscode";
      version = cppExtsThemesVer;
      sha256 = "sha256-YWA5UsA+cgvI66uB9d9smwghmsqf3vZPFNpSCK+DJxc=";
    }
    {
      name = "cpp-devtools";
      publisher = "ms-vscode";
      version = cppExtsDevToolsVer;
      sha256 = "sha256-g8ZXdEgKB6okJEVXvFQMGz5oDMsOh5mWzl50B/etVjw=";
    }
    {
      publisher = "formulahendry";
      name = "code-runner";
      version = codeRunnerVer;
      sha256 = "sha256-TI5K6n3QfJwgFz5xhpdZ+yzi9VuYGcSzdBckZ68DsUQ=";
    }
  ];
in {
  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions =
        (with pkgs.vscode-extensions; [
          catppuccin.catppuccin-vsc
          bbenoist.nix
          kamadorueda.alejandra
          jeff-hykin.better-nix-syntax
          mads-hartmann.bash-ide-vscode
        
          # c/cpp extensions
          ms-vscode.cpptools-extension-pack
          ms-vscode.cpptools
          ms-vscode.cmake-tools
          ms-vscode.makefile-tools
          #divyanshuagrawal.competitive-programming-helper

          # Java Extensions
          #vscjava.vscode-gradle
          vscjava.vscode-java-debug
          vscjava.vscode-java-dependency
          vscjava.vscode-java-pack
          vscjava.vscode-java-test
          vscjava.vscode-maven
          redhat.java

          # python
          ms-python.python
          #github.copilot
        ])
        #++ codeRunnerExts
        ++ cppExtraExts;

      userSettings = lib.mkForce {
        # Java settings for NixOS
        "security.workspace.trust.untrustedFiles" = "open";
        "java.jdt.ls.java.home" = "${pkgs.jdk21}/lib/openjdk";

        "java.configuration.runtimes" = [
          {
            name = "JavaSE-21";
            path = "${pkgs.jdk21}/lib/openjdk";
            default = true;
          }
        ];

        "java.import.gradle.java.home" = "${pkgs.jdk21}/lib/openjdk";
        "java.import.maven.java.home" = "${pkgs.jdk21}/lib/openjdk";
        "java.debug.settings.console" = "integratedTerminal";
        "code-runner.runInTerminal" = true;
        "code-runner.saveFileBeforeRun" = true;

        "chat.disableAIFeatures" = false;
        "files.autoSave" = "afterDelay";
        "files.autoSaveDelay" = 1000;

        "git.autofetch" = true;
        "git.enableSmartCommit" = true;
        "git.confirmSync" = false;

        "redhat.telemetry.enabled" = true;
        "explorer.confirmDelete" = false;

        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "catppuccin-mocha";
        # "workbench.colorTheme" = "Stylix";
        # "workbench.iconTheme" = "Stylix";

        "workbench.activityBar.compact" = "true";

        "terminal.integrated.profiles.linux" = {
          "bash" = {
            "path" = "bash";
            "icon" = "terminal-bash";
          };

          "zsh" = {
            "path" = "/etc/profiles/per-user/ratul/bin/zsh";
          };

          "fish" = {
            "path" = "fish";
          };

          "tmux" = {
            "path" = "tmux";
            "icon" = "terminal-tmux";
          };

          "pwsh" = {
            "path" = "pwsh";
            "icon" = "terminal-powershell";
          };
        };
      };
    };
  };

  # Java runtime (IMPORTANT)
  home.packages = with pkgs; [
    jdk21
  ];

  nixpkgs.config.allowUnfree = true;
}

