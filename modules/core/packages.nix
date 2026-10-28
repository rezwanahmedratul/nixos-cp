{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Web Browsers
    google-chrome
    brave

    # Terminal Emulators
    alacritty

    # IDEs and Text Editors
    codeblocks
    vscode
    kdePackages.kate
    vim
    neovim
    nano

    # C & C++ Compiler Toolchain & Debugging
    gcc
    gdb
    clang
    clang-tools
    cmake
    gnumake
    valgrind
    lldb

    # Python Toolchain
    python3
    pypy3

    # Java Toolchain (ICPC LTS standard)
    jdk21

    # Benchmarking, Diffing & System Verification
    time # GNU time (-v for memory & CPU profiling)
    diffutils # diff, cmp
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

    # Offline Documentation
    man-pages
    man-pages-posix
    cppreference-doc

    # Essential KDE Applications
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.kcalc
    kdePackages.ark
  ];

  # Developer Documentation
  documentation.enable = true;
  documentation.man.enable = true;
  documentation.dev.enable = true;
}
