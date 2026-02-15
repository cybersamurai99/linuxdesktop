#!/bin/bash

echo "🚀 Starting CachyOS Optimization for RTX 4090..."

# 1. Update the entire system and keys
echo "🔄 Updating system (pacman)..."
sudo pacman -Syu --noconfirm

# 2. Hardware Detection (Ensures NVIDIA drivers are correct)
# This will detect the 4090 and install the 'nonfree' optimized profile if missing.
echo "🔍 Running Hardware Detection..."
sudo chwd -a

# 3. Install the Gaming Meta-Packages
# This includes Steam, Lutris, Wine-CachyOS, and necessary fonts/libs.
echo "🎮 Installing CachyOS Gaming Meta-packages..."
sudo pacman -S cachyos-gaming-meta cachyos-gaming-applications --noconfirm

# 4. Install Performance Monitoring Tools
echo "📊 Installing MangoHud and Overlay tools..."
sudo pacman -S mangohud goverlay --noconfirm

# 5. RTX 4090 Specific: Enable Wayland Explicit Sync
# This is crucial for avoiding flickering on NVIDIA with KDE/GNOME Wayland.
echo "✨ Setting NVIDIA DRM Modeset..."
sudo sed -i 's/MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
sudo mkinitcpio -P

# 6. Apply High-End System Tweaks
echo "🧠 Optimizing system limits for high-end gaming..."
echo "vm.max_map_count=2147483642" | sudo tee /etc/sysctl.d/90-gaming.conf
sudo sysctl -p /etc/sysctl.d/90-gaming.conf

echo "✅ Setup complete! REBOOT to apply the NVIDIA kernel modules."
