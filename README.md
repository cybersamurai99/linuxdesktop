# linuxdesktop

A collection of scripts for setting up and optimizing Linux distributions, primarily focused on gaming with high-end hardware (RTX 4090) and storage management.

## Scripts

### Desktop Setup
- **[Setup-Fedora.sh](./Setup-Fedora.sh)**: A multi-stage setup for Fedora 43/44. Features include DNF optimization, NVIDIA driver installation (with akmod waiting), multimedia codecs, and common app installation (Steam, VS Code, Docker).
- **[ubuntu25.10-gemini.sh](./ubuntu25.10-gemini.sh)**: Quick setup for Ubuntu 25.10, including NVIDIA 565 drivers, gaming essentials (MangoHud, GameMode), and memory mapping optimizations.
- **[cachyos-gemini.sh](./cachyos-gemini.sh)**: Optimization script for CachyOS. Enables Wayland Explicit Sync for NVIDIA and installs CachyOS-specific gaming meta-packages.

### Storage & Infrastructure
- **[LVM-Caching-NAS.sh](./LVM-Caching-NAS.sh)**: Configures a high-performance NAS storage pool using a RAID 5 array cached by an NVMe SSD via LVM. Formats the resulting volume with XFS.

## Usage

Each script generally requires root privileges and should be inspected before execution.

```bash
# Example for Fedora
chmod +x Setup-Fedora.sh
./Setup-Fedora.sh
```
