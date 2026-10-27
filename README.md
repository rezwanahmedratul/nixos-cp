# NixOS Competitive Programming Lab Environment

A declarative, reproducible NixOS configuration tailored for university competitive programming (CP) computer labs. Designed to be deployed identically across all lab machines or run as a live contest environment.

---

## Features

- **Desktop Environment**: Modern **KDE Plasma 6** with Wayland and SDDM display manager.
- **Contestant User Experience**:
  - Dedicated non-privileged participant account (custom username chosen during installation, e.g. `student`, `pc01`) with automatic login into KDE Plasma.
  - Pre-created `~/workspace` directory for solutions and test inputs.
  - Sleep, suspend, and hibernation disabled to prevent interruptions during contest thinking periods.
  - Strict NTP time synchronization (`systemd-timesyncd`).
  - Desktop shortcuts for **Offline C++ Reference** and **Reset Contest Workspace**.
- **Comprehensive Toolchain**:
  - **IDEs & Editors**: Code::Blocks, Visual Studio Code (customized via Home Manager), VSCodium, Geany, Kate, Vim, Neovim.
  - **C & C++**: GCC (g++), Clang, GDB, LLDB, Clang-Tools (clang-format), CMake, GNU Make, Valgrind.
  - **Python**: Python 3 and PyPy3 (crucial for time-sensitive Python submissions).
  - **Java**: OpenJDK 21 (ICPC standard LTS).
  - **JavaScript**: Node.js.
  - **Rust**: rustc & cargo.
  - **Go**: go compiler and tools.
  - **Benchmarking & Diffing**: GNU `time` (`time -v` for memory/CPU profiling), `diffutils` (`diff`, `cmp`), `patch`, `tree`, `jq`.
  - **Offline Documentation**: Full offline C++ standard library documentation (`cppreference-doc`) and developer man pages (`man-pages`, `man-pages-posix`).
- **Lab Administration & Maintenance**:
  - Administrative account (`admin`) with `wheel` (sudo) privileges.
  - Declarative disk partitioning via **Disko** (EFI + ext4 + RAM-based swap for memory paging without hibernation).
  - Weekly automatic Nix garbage collection and store deduplication.
  - Scripted contest workspace reset utilities for single machines or whole lab fleets.
  - Pre-configured ISO generation target for creating bootable live USBs.

---

## Directory Layout

```
.
├── flake.nix                          # Flake entry point (lab-pc and contest-iso outputs)
├── flake.lock                         # Pinned dependency lockfile
├── install.sh                         # One-liner quick bootstrap script
├── hosts/
│   └── lab-pc/
│       ├── configuration.nix          # Machine configuration (imports modules/core)
│       ├── hardware-configuration.nix # Hardware scan template
│       └── disko.nix                  # Declarative disk partitioning layout
├── modules/
│   ├── core/                          # Modular system-level configuration
│   │   ├── default.nix                # Aggregator importing all core modules
│   │   ├── boot.nix                   # systemd-boot bootloader & kernel settings
│   │   ├── network.nix                # NetworkManager, hostname, firewall
│   │   ├── plasma.nix                 # KDE Plasma 6 + SDDM with Wayland + autoLogin
│   │   ├── packages.nix               # All contest compilers, IDEs, and tools
│   │   ├── services.nix               # Timesyncd, SSH, PipeWire, anti-sleep
│   │   ├── fonts.nix                  # Fira Code & JetBrains Mono coding fonts
│   │   ├── security.nix               # Sudo permissions & dconf
│   │   ├── system.nix                 # Nix GC, flakes, unfree packages, locale
│   │   ├── contest-tools.nix          # Reset script & desktop shortcuts
│   │   └── user.nix                   # System users & Home Manager hook
│   └── home/                          # User-level Home Manager modules
│       ├── default.nix                # Home aggregator
│       └── vscode.nix                 # Full VS Code configuration
├── iso/
│   └── configuration.nix              # Bootable Live USB / Installer ISO configuration
└── scripts/
    ├── install-lab.sh                 # Unified installer (Live USB & in-place switch)
    └── reset-lab.sh                   # Remote workspace reset script for lab fleets
```

---

## Quick Install (One-Liner for Lab Machines)

On any target PC (either running a **Live USB installer** or an **already installed minimal NixOS**), open a terminal and run:

### Method 1: Step-by-Step (Enter `nix-shell` first)
```bash
# 1. Spawn an ephemeral shell with basic tools
nix-shell -p git curl vim pciutils

# 2. Run the quick installer
sh <(curl -sSL https://raw.githubusercontent.com/rezwanahmedratul/nixos-cp/main/install.sh)
```

### Method 2: Single One-Liner
```bash
nix-shell -p git curl vim pciutils --run "bash <(curl -sSL https://raw.githubusercontent.com/rezwanahmedratul/nixos-cp/main/install.sh)"
```

The installer will automatically:
1. Clone this repository into `~/nixos-cp`.
2. Detect whether it is running on a **Live USB ISO** or an **Already Installed NixOS System**.
3. Sizing swap dynamically based on physical RAM (without hibernation).
4. Execute the appropriate installation or switch sequence without manual file editing.

---

## Installation & Deployment Workflows

The unified setup script (`./scripts/install-lab.sh`) automatically detects the host environment.

### Option 1: On an Already Installed NixOS System (In-Place Switch)

Use this if NixOS is already running on the computer:

1. Clone this repository:
   ```bash
   git clone https://github.com/rezwanahmedratul/nixos-cp.git
   cd nixos-cp
   ```
2. Run the installer script:
   ```bash
   ./scripts/install-lab.sh
   # Or specify options upfront:
   # ./scripts/install-lab.sh --user student --admin-pass mypassword
   ```
   The script:
   - Prompts for the contest participant username and unified administrator/sudo password.
   - Detects the installed system, automatically generates a fresh hardware configuration for the machine, and preserves existing disks (Disko disabled).
   - Synchronizes the configuration to `/home/admin/nixos-cp`.
   - **Removes all other existing user accounts** and wipes their old home directories.
   - Switches the active generation to `.#lab-pc`.
3. Reboot to complete session transition:
   ```bash
   sudo reboot
   ```

### Option 2: Fresh Installation from Live USB (Disko Partitioning)

Use this when booting from a blank disk or re-imaging a lab PC:

1. Boot any NixOS Live USB.
2. Clone this repository:
   ```bash
   git clone https://github.com/rezwanahmedratul/nixos-cp.git
   cd nixos-cp
   ```
3. Run the installer with your target drive:
   ```bash
   sudo ./scripts/install-lab.sh /dev/sda
   # Or /dev/nvme0n1 for NVMe SSDs
   ```
   The script prompts for the participant username and admin password, calculates swap size based on RAM, partitions with Disko, scans hardware, and executes `nixos-install`.
4. Reboot into the installed system:
   ```bash
   sudo reboot
   ```

   *Note: The installer sets the same password for `admin` (sudo) and `root`, and automatically copies the repository into `/home/admin/nixos-cp` (owned by `admin:users` with `0700` home directory permissions).*

### Swap Sizing (No Hibernation)

During fresh installation, swap is automatically calculated to provide memory paging headroom without wasting disk space:
- **$\le$ 2 GB RAM**: Swap = equal to RAM (e.g. `2G`)
- **4 GB – 16 GB RAM**: Swap = `4G`
- **$>$ 16 GB RAM**: Swap = `8G`

You can manually specify a swap size using the `--swap` flag:
```bash
sudo ./scripts/install-lab.sh --live /dev/sda --swap 4G
```

### Manual Override Flags

You can force a specific mode at any time:
- `./scripts/install-lab.sh --installed`: Force in-place rebuild mode without disk partitioning.
- `./scripts/install-lab.sh --live /dev/sda`: Force fresh Disko install mode.
- `./scripts/install-lab.sh --swap 8G`: Custom swap size.

---

### Option 3: Build a Custom Contest Live USB / Installer ISO

You can generate a bootable ISO that contains the entire KDE Plasma desktop and contest toolchain pre-baked. This allows running contests directly off USB drives without altering existing operating systems on lab PCs, or installing completely offline:

```bash
# Build the ISO image (outputs to ./result/iso/*.iso)
nix build .#iso

# Write the image to a USB flash drive
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

---

### Option 4: Remote Deployment from Admin Workstation (Fleet Management)

If lab computers are already running NixOS and connected to the local network:

1. Test changes remotely without committing to bootloader:
   ```bash
   nixos-rebuild test --flake .#lab-pc --target-host admin@192.168.1.50 --use-substitutes
   ```
2. Activate and set as default bootloader entry:
   ```bash
   nixos-rebuild switch --flake .#lab-pc --target-host admin@192.168.1.50 --use-substitutes
   ```

*(For managing 20+ machines simultaneously, Colmena or deploy-rs can be added to deploy in parallel).*

---

## Contest Management & Operations

### Auto-Login & Contestant Session
When a lab PC powers on, it automatically logs into KDE Plasma under the participant user account configured during installation (e.g. `student`, `pc01`). No password prompt is required for students.

### Resetting Between Contests
To ensure a clean environment between rounds:

- **From the desktop**: The contestant or invigilator can double-click the **"Reset Contest Workspace"** shortcut on the desktop or run:
  ```bash
  reset-contest-workspace
  ```
  This empties `~/workspace`, purges browser caches, and cleans IDE temporary state.

- **Remotely across the entire lab**: From your admin machine, run:
  ```bash
  ./scripts/reset-lab.sh 192.168.1.101 192.168.1.102 192.168.1.103
  ```

---

## Network Filtering & Domain Whitelisting

During competitive programming contests, you often want participants to access only authorized competition platforms (or local contest servers) while preventing external cheating, messaging, or solution lookups.

The configuration provides **per-user network filtering**:
- **Administrator (`admin`) and root**: Retain **100% full, unrestricted internet access** to download packages, update the system, and run administrative tasks.
- **Participants**: Strictly restricted to whitelisted domains and authorized local subnets. All other outbound internet traffic is dropped.

### Declarative Domain Whitelist
Configure allowed domains in [`hosts/lab-pc/configuration.nix`](hosts/lab-pc/configuration.nix):

```nix
lab.networkFilter = {
  enable = true;
  allowedDomains = [
    "codeforces.com"
    "codeforces.org"
    "kattis.com"
    "open.kattis.com"
    "atcoder.jp"
    "cses.fi"
    "vjudge.net"
    "icpc.global"
    "domjudge.cs.myuniversity.edu" # Custom university contest judge
  ];
  allowedIPs = [
    "127.0.0.0/8"      # Local loopback
    "10.0.0.0/8"       # Campus network
    "172.16.0.0/12"    # Private LAN
    "192.168.0.0/16"   # Local contest servers (e.g. DOMjudge, PC2)
  ];
};
```

To allow full unrestricted internet for everyone, simply set `lab.networkFilter.enable = false;`.

### Live / Emergency Whitelisting Tools
If a domain needs to be allowed immediately during a live contest without rebuilding:

```bash
# Whitelist a new domain for contestants instantly on the fly:
sudo contest-allow-domain customjudge.net

# Inspect currently whitelisted domains, subnets, and active kernel IP sets:
contest-network-status
```

---

## Customization

- **Change Hostname**: Override `networking.hostName` in `modules/core/network.nix` or in `hosts/lab-pc/configuration.nix`.
- **Adjust Timezone**: Update `time.timeZone = "UTC";` in `modules/core/system.nix` to your local timezone (e.g., `"Asia/Dhaka"`, `"America/New_York"`).
- **Add Extra Packages**: Add packages to `environment.systemPackages` in `modules/core/packages.nix`.
- **Customize VS Code**: Modify extensions, themes, or editor settings in `modules/home/vscode.nix`.
