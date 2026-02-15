#!/bin/bash
# Taked from https://github.com/wz790/Fedora-Noble-Setup
# Get the free repository (most stuff you need)
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm

# Get the nonfree repository (NVIDIA drivers, some codecs)
sudo dnf install -y \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Update everything so it all plays nice together
sudo dnf group upgrade core -y
sudo dnf check-update

# Update everything
sudo dnf update -y

# If it updated the kernel, reboot
# sudo reboot

## Firmware updates ##
# See what can be updated
sudo fwupdmgr get-devices

# Refresh the firmware database
sudo fwupdmgr refresh --force

# Check for updates
sudo fwupdmgr get-updates

# Apply them
sudo fwupdmgr update

# If it updated, reboot
# sudo reboot


# Remove the limited Fedora repo
flatpak remote-delete fedora
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo


## NVidia Drivers ##
# Install kernel headers and dev tools
sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
  libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig

# Enable RPM Fusion (if not already done)
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Set open kernel module macro (one-time step for RTX 4000+)
sudo sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'

sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
# Now wait. Seriously. It takes 5–15 minutes to build the module.
# sudo journalctl -f -u akmods
sudo reboot

## Make media work ##
# Replace the neutered ffmpeg with the real one
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

# Install all the GStreamer plugins
sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} \
  gstreamer1-plugin-openh264 gstreamer1-libav lame\* \
  --exclude=gstreamer1-plugins-bad-free-devel

# Install multimedia groups
sudo dnf group install -y multimedia
sudo dnf group install -y sound-and-video

# Install VA-API stuff
sudo dnf install -y ffmpeg-libs libva libva-utils
sudo dnf install -y libva-nvidia-driver

# Install the Cisco codec (it's free but weird licensing)
sudo dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264

# Enable the Cisco repo
sudo dnf config-manager --set-enabled fedora-cisco-openh264
sudo dnf update -y

# Install dependencies
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig

# Install the fonts
sudo rpm -i --nodigest --nosignature https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

# Update font cache
sudo fc-cache -fv


# Install FUSE
sudo dnf install -y fuse fuse-libs
flatpak install -y flathub it.mijorus.gearlever

# Create the service unit
sudo tee /etc/systemd/system/flatpak-update.service > /dev/null <<'EOF'
[Unit]
Description=Update Flatpak apps automatically

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --noninteractive
EOF

# Create the timer unit
sudo tee /etc/systemd/system/flatpak-update.timer > /dev/null <<'EOF'
[Unit]
Description=Run Flatpak update every 24 hours
Wants=network-online.target
Requires=network-online.target
After=network-online.target

[Timer]
OnBootSec=120
OnUnitActiveSec=24h

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable the timer
sudo systemctl daemon-reload
sudo systemctl enable --now flatpak-update.timer

# Check the status to verify everything is working
sudo systemctl status flatpak-update.timer


## Make things faster
sudo systemctl disable NetworkManager-wait-online.service



#Gaming stuff
sudo dnf install -y steam

## other apps ##
sudo dnf install -y vlc
flatpak install -y flathub com.github.tchx84.Flatseal


### Clean things ##
# Clean package cache
sudo dnf clean all

# Remove orphaned packages
sudo dnf autoremove -y
