# NixOS Competitive Programming Lab Environment

A declarative, reproducible NixOS configuration tailored for university competitive programming (CP) computer labs. Designed to be deployed identically across all lab machines or run as a live contest environment.

---

## Features

- **Desktop Environment**: Modern **KDE Plasma 6** with Wayland and SDDM display manager.
- **Contestant User Experience**:
  - Dedicated non-privileged `contestant` account with automatic login.
  - Pre-created `~/workspace` directory for solutions and test inputs.
  - Sleep, suspend, and hibernation disabled to prevent interruptions during contest thinking periods.
  - Strict NTP time synchronization (`systemd-timesyncd`).
  - Desktop shortcuts for **Offline C++ Reference** and **Reset Contest Workspace**.
- **Comprehensive Toolchain**:
  - **IDEs & Editors**: Code::Blocks, Visual Studio Code (unfree enabled), VSCodium, Geany, Kate, Vim, Neovim.
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
  - Declarative disk partitioning via **Disko** (EFI + ext4/btrfs).
  - Weekly automatic Nix garbage collection and store deduplication.
  - Scripted contest workspace reset utilities for single machines or whole lab fleets.
  - Pre-configured ISO generation target for creating bootable live USBs.

---

## Directory Layout

```
.
├── flake.nix                          # Flake entry point (lab-pc and contest-iso outputs)
├── flake.lock                         # Pinned dependency lockfile
├── hosts/
│   ├── common/
│   │   ├── default.nix                # Base OS configuration shared by all lab machines
│   │   └── users.nix                  # Administrator user definition
│   └── lab-pc/
│       ├── configuration.nix          # Machine configuration
│       ├── hardware-configuration.nix # Hardware scan template
│       └── disko.nix                  # Declarative disk partitioning layout
├── modules/
│   └── nixos/
│       ├── contest-environment.nix    # Reusable contest tools, languages & user module
│       └── desktop-kde.nix            # KDE Plasma 6 + SDDM + PipeWire audio module
├── iso/
│   └── configuration.nix              # Bootable Live USB / Installer ISO configuration
└── scripts/
    ├── install-lab.sh                 # One-command installer for lab machines
    └── reset-lab.sh                   # Remote workspace reset script for lab fleets
```

---

## Installation & Deployment Workflows

Before applying commands, verify whether you are working **locally on the target machine** or **remotely from an admin workstation**.

### Option 1: One-Command Install via Live USB (Recommended for Lab Setup)

1. Boot any NixOS installer Live USB on the target lab computer.
2. Clone this repository onto the live environment:
   ```bash
   git clone https://github.com/<your-org>/nixos-cp.git
   cd nixos-cp
   ```
3. Run the automated installation script:
   ```bash
   sudo ./scripts/install-lab.sh /dev/sda
   # Use /dev/nvme0n1 if the machine has an NVMe drive
   ```
4. When finished, reboot:
   ```bash
   sudo reboot
   ```

### Option 2: Build a Custom Contest Live USB / Installer ISO

You can generate a bootable ISO that contains the entire KDE Plasma desktop and contest toolchain pre-baked. This allows running contests directly off USB drives without altering existing operating systems on lab PCs, or installing completely offline:

```bash
# Build the ISO image (outputs to ./result/iso/*.iso)
nix build .#iso

# Write the image to a USB flash drive
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### Option 3: Remote Deployment from Admin Workstation (Fleet Management)

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
When a lab PC powers on, it automatically logs into KDE Plasma under the `contestant` user account. No password prompt is required for students.

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

## Customization

- **Change Hostname**: Override `networking.hostName` in `hosts/lab-pc/configuration.nix` or create per-machine host definitions (e.g., `hosts/pc-01/configuration.nix`).
- **Adjust Timezone**: Update `time.timeZone = "UTC";` in `hosts/common/default.nix` to your local timezone (e.g., `"Asia/Dhaka"`, `"America/New_York"`).
- **Add Extra Packages**: Add packages to `contest.extraPackages` in `hosts/common/default.nix`.

