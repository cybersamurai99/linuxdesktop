#!/bin/bash

echo "🦁 Starting Ubuntu 25.10 Setup for RTX 4090..."

# 1. Update and Upgrade
echo "🔄 Refreshing package lists..."
sudo apt update && sudo apt upgrade -y

# 2. Add Graphics Drivers PPA (Latest NVIDIA Drivers)
echo "📦 Adding Graphics Drivers PPA..."
sudo add-apt-repository ppa:graphics-drivers/ppa -y
sudo apt update

# 3. Install NVIDIA Drivers & Vulkan
# We target the 'dist-upgrade' version to ensure kernel headers match
echo "🎮 Installing NVIDIA Drivers and 32-bit support..."
sudo apt install -y nvidia-driver-565 nvidia-settings libvulkan1 libvulkan1:i386

# 4. Install Media Codecs
# EULA prompt is bypassed; if it appears, use TAB to select OK.
echo "🎥 Installing Media Codecs..."
sudo apt install -y ubuntu-restricted-extras libavcodec-extra

# 5. Install Gaming Essentials
echo "🕹️ Installing Steam, Lutris, and MangoHud..."
sudo apt install -y steam mangohud gamemode

# 6. Performance Tweak: Increase Virtual Memory Mapping
# Necessary for heavy titles like Star Citizen or modded Cyberpunk 2077
echo "🧠 Optimizing memory mapping for gaming..."
echo "vm.max_map_count=2147483642" | sudo tee /etc/sysctl.d/90-gaming.conf
sudo sysctl -p /etc/sysctl.d/90-gaming.conf

# 7. Clean up
echo "🧹 Cleaning up unnecessary packages..."
sudo apt autoremove -y

echo "✅ Setup finished! REBOOT is required to activate the NVIDIA driver."
