#!/bin/bash

pause() {
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

echo "🚀 Starting Fedora 43 Gaming Setup for RTX 4090..."
echo "This is a multi-stage setup script. It will reboot your system multiple times to ensure proper driver installation and configuration."

pause

# Path to the state file to track progress across reboots
STATE_FILE="$HOME/.fedora_setup_stage"
[ ! -f "$STATE_FILE" ] && echo "1" > "$STATE_FILE"

STAGE=$(cat "$STATE_FILE")

# Function to handle errors
error_exit() {
    echo "Error occurred at Stage $STAGE. Check logs."
    exit 1
}

case $STAGE in
    1)
        echo "--- STAGE 1: Repository Setup and System Update ---"
        
        # enable passwordless sudo
        echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER >/dev/null && sudo chmod 0440 /etc/sudoers.d/$USER

        echo "⚡ Optimizing DNF5..."
        sudo sed -i 's/\[main\]/\[main\]\nmax_parallel_downloads=10/' /etc/dnf/dnf.conf
        
        # Install RPM Fusion (Free and Nonfree)
        sudo dnf5 install -y \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

        # Update core groups and system packages
        sudo dnf5 group upgrade core -y
        sudo dnf5 update -y
        
        echo "2" > "$STATE_FILE"
        echo "System updated. Rebooting to initialize new kernel..."
        sudo reboot
        ;;

    2)
        echo "--- STAGE 2: Firmware and Flatpak Configuration ---"
        # Refresh firmware database and apply updates
        sudo fwupdmgr refresh --force
        sudo fwupdmgr get-updates -y
        sudo fwupdmgr update -y

        # Configure Flatpak (Switch from Fedora-limited to Flathub)
        flatpak remote-delete fedora --force
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

        echo "3" > "$STATE_FILE"
        echo "Firmware updated. Rebooting to apply hardware changes..."
        sudo reboot
        ;;

    3)
        echo "--- STAGE 3: NVIDIA Driver Installation ---"
        # Install headers and development tools required for Akmods
        sudo dnf5 install -y kernel-devel kernel-headers gcc make dkms acpid \
            libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig

        # Enable Open Kernel Module for RTX 4000+ cards
        sudo sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'

        # Install the driver and CUDA
        sudo dnf5 install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

        echo "Waiting for Akmods to build the Nvidia kernel module..."
        echo "This can take 5-10 minutes. Do not cancel."
        
        # Use a loop to wait until the driver is actually built
        while [[ $(ps aux | grep -i "[a]kmods" | wc -l) -gt 0 ]]; do
            sleep 10
            echo "Still building..."
        done

        # Optimization for High-VRAM GPUs (RTX 4090)
        echo "🧠 Tweaking system for 4090 performance..."
        echo "vm.max_map_count=2147483642" | sudo tee /etc/sysctl.d/90-gaming.conf
        sudo sysctl -p /etc/sysctl.d/90-gaming.conf

        echo "4" > "$STATE_FILE"
        echo "Nvidia drivers installed and built. Rebooting to activate drivers..."
        sudo reboot
        ;;

    4)
        echo "--- STAGE 4: Multimedia, Apps, and Optimization ---"
        # Replace neutered ffmpeg with the full version
        sudo dnf5 swap -y ffmpeg-free ffmpeg --allowerasing

        # Install GStreamer plugins and Multimedia groups
        sudo dnf5 install -y gstreamer1-plugins-{bad-\*,good-\*,base} \
            gstreamer1-plugin-openh264 gstreamer1-libav lame\* \
            --exclude=gstreamer1-plugins-bad-free-devel
        sudo dnf5 group install -y multimedia sound-and-video

        # VA-API and Cisco Codecs
        sudo dnf5 install -y ffmpeg-libs libva libva-utils libva-nvidia-driver
        sudo dnf5 config-manager --set-enabled fedora-cisco-openh264
        sudo dnf5 update -y

        # Microsoft Fonts
        sudo dnf5 install -y curl cabextract xorg-x11-font-utils fontconfig
        sudo rpm -i --nodigest --nosignature https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
        sudo fc-cache -fv

        # FUSE and GearLever
        sudo dnf5 install -y fuse fuse-libs
        flatpak install -y flathub it.mijorus.gearlever

        # Setup Automated Flatpak Update Timer
        sudo tee /etc/systemd/system/flatpak-update.service > /dev/null <<'EOF'
[Unit]
Description=Update Flatpak apps automatically
[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --noninteractive
EOF

        sudo tee /etc/systemd/system/flatpak-update.timer > /dev/null <<'EOF'
[Unit]
Description=Run Flatpak update every 24 hours
[Timer]
OnBootSec=120
OnUnitActiveSec=24h
[Install]
WantedBy=timers.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable --now flatpak-update.timer

        # Speed optimization: Disable wait-online
        sudo systemctl disable NetworkManager-wait-online.service

        # Steam and VLC installation
        sudo dnf5 install -y steam vlc
        flatpak install -y flathub com.github.tchx84.Flatseal

        # Enable Fn key mode for Nuphy keyboards
        echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf
        echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode

        # Enable git credential manager for HTTPS repos
        sudo dnf install -y git git-credential-libsecret
        sudo dnf copr enable -y matthickford/git-credential-manager
        sudo dnf install -y git-credential-manager
        git config --global credential.helper "/usr/bin/git-credential-manager"
        git config --global credential.credentialStore libsecret

        # Install VScode
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf check-update
        sudo dnf install -y code

        # Install docker and docker-compose
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER

        # Install easyeffects
        sudo dnf install -y easyeffects

        # install opencode (disabled as optional)
        # curl -fsSL https://opencode.ai/install | bash

        # Final Cleanup
        sudo dnf5 autoremove -y
        sudo dnf5 clean all
        
        # Remove state file so it starts fresh if run again in the future
        rm "$STATE_FILE"
        echo "----------------------------------------------------"
        echo "SETUP COMPLETE! Your Fedora 43 system is ready."
        echo "----------------------------------------------------"
        ;;

esac
